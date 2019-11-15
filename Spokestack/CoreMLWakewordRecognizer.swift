//
//  CoreMLWakewordRecognizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 6/6/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CoreML
import Speech

/**
This pipeline component streams audio samples and uses CoreML models to detect and aggregate keywords (i.e. [null], up, dog) into phrases (up dog) to process for wakeword recognition. Once a wakeword phrase is detected, speech pipeline activation is called. 

Once speech pipeline coordination via `startStreaming`is received, the recognizer begins streaming buffered frames that are normalized and then converted to the magnitude Short-Time Fourier Transform (STFT) representation over a hopped sliding window. This linear spectrogram is then converted to a mel spectrogram via a "filter" CoreML model.  The mel spectrogram represents the features to be passed to the keyword classifier, which is implemented in a "detect" CoreML model. This classifier outputs posterior probabilities for each keyword (and a null output 0, which represents non-keyword speech). These mel frames are batched together into a sliding window.
 
 The detector's outputs are considered noisy, so they are maintained in a sliding window and passed through a moving mean filter. The smoothed posteriors are then maintained in another sliding window for phrasing. The phraser attempts to match one of the configured keyword sequences using the maximum posterior for each word. If a sequence match is found, the speech pipeline is activated.
 
Upon pipeline activation, the recognizer completes processing and awaits another coordination event. Once speech pipeline coordination via `stopStreaming` is received, the recognizer stops processing and awaits another coordination event.
*/
@available(*, deprecated, message: "Training is no longer supported for convolutional wakeword models, use TFLiteWakewordRecognizer instead.")
public class CoreMLWakewordRecognizer: NSObject {
    
    // MARK: Public properties
    
    /// Singleton instance.
    @objc public static let sharedInstance: CoreMLWakewordRecognizer = CoreMLWakewordRecognizer()
    
    /// Configuration for the recognizer.
    public var configuration: SpeechConfiguration? = SpeechConfiguration() {
        didSet {
            if configuration != nil {
                self.parseConfiguration()
                self.setAttentionModels()
                self.setConfiguration()
                self.validateConfiguration()
            }
        }
    }
    
    /// Global state for the speech pipeline.
    public var context: SpeechContext = SpeechContext()
    
    /// Delegate which receives speech pipeline control events.
    public weak var delegate: SpeechEventListener?

    // MARK: Private properties
    
    private var vad: WebRTCVAD = WebRTCVAD()
    
    private var filterModel: Filter?

    private var detectModel: Detect?
    
    /// Keyword & phrase preallocated buffers
    
    private var words: Array<String> = []
    private var phrases: Array<Array<Int>> = [[Int]]()
    private var phraseSum: Array<Float> = []
    private var phraseArg: Array<Int> = []
    private var phraseMax: Array<Float> = []
    
    /// Audio Signal Normalization
    
    private var rmsTarget: Float = 0.0
    private var rmsAlpha: Float = 0.0
    private var rmsValue: Float = 0.0
    private var preEmphasis: Float = 0.0
    private var prevSample: Float = 0.0
    
    /// STFL / MEL Filterbank
    
    private var fft: FFT!
    private var fftWindow: Array<Float> = []
    private var fftFrame: Array<Float> = []
    private var hopLength: Int = 0
    private var melWidth: Int = 0
    
    /// Sliding Window Buffers
    
    private var sampleWindow: RingBuffer<Float>!
    private var frameWindow: RingBuffer<Float>!
    private var smoothWindow: RingBuffer<Float>!
    private var phraseWindow: RingBuffer<Float>!

    /// Wakeword Activation Management
    
    private var minActive: Int = 0
    private var maxActive: Int = 0
    private var activeLength: Int = 0
    
    /// Tracing
    private var traceLevel: Trace.Level = Trace.Level.NONE
    private var sampleCollector: Array<Float>?
    private var fftFrameCollector: String?
    private var filterCollector: Array<Float>?
    private var detectCollector: String?
    
    // MARK: NSObject implementation

    deinit {
    }
    
    public override init() {
        super.init()
    }
        
    // MARK: Configuration processing
    
    private func parseConfiguration() -> Void {
        if let c = self.configuration {

            /// Parse the list of keywords.
            /// Reserve the 0th index in words for the non-keyword class.
            let wakewords: Array<String> = c.wakewords.components(separatedBy: ",")
            self.words = Array(repeating: "", count: wakewords.count +  1)
            for (index, _) in self.words.enumerated() {
                let indexOffset: Int = index + 1
                if indexOffset < self.words.count {
                    self.words[indexOffset] = wakewords[indexOffset - 1]
                }
            }

            /// Parse the keyword phrases
            let wakePhrases: Array<String> = c.wakePhrases.components(separatedBy: ",")
            self.phrases = Array<Array<Int>>.init(repeating: [0], count: wakePhrases.count)
            for (i, phrase) in wakePhrases.enumerated() {
                let wakePhraseArray: Array<String> = phrase.components(separatedBy: " ")
                Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "wakePhraseArray \(wakePhraseArray)", delegate: self.delegate, caller: self)
                /// Allocate an additional (null) slot at the end of each phrase,
                /// which forces the phraser to continue detection until the end
                /// of the final keyword in each phrase
                self.phrases[i] = Array<Int>.init(repeating: 0, count: wakePhrases.count + 1)
                for (j, keyword) in wakePhraseArray.enumerated() {
                    // verify that each keyword in the phrase is a known keyword
                    guard let k: Int = wakewords.firstIndex(of: keyword) else {
                        assertionFailure("CoreMLWakewordRecognizer parseConfiguration wakewords did not contain \(keyword)")
                        return
                    }
                    // TODO: verify this check is not necessary because the wakePhraseArray.count == phrases.count
                    if j < self.phrases[i].count {
                        self.phrases[i][j] = k + 1
                    }
                }
            }
        }
    }
    
    private func setAttentionModels() -> Void {
        if let c = self.configuration {
            do {
                /// NB a compiled (.mlmodelc) CoreML model is assumed to be on detectModelPath.
                let detectModelURL = URL.init(fileURLWithPath: c.detectModelPath)
                detectModel = try Detect(contentsOf: detectModelURL)
                let filterModelURL = URL.init(fileURLWithPath: c.filterModelPath)
                filterModel = try Filter(contentsOf: filterModelURL)
            } catch let message {
                self.delegate!.didError(WakewordModelError.model("CoreMLWakewordRecognizer setAttentionModels \(message)"))
            }
        }
    }
    
    private func setConfiguration() -> Void {
        
        if let c = self.configuration {
            /// Tracing
            self.traceLevel = c.tracing
            if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
                self.sampleCollector = []
                self.fftFrameCollector = ""
                self.filterCollector = []
                self.detectCollector = ""
            }
            
            /// VAD
            do {
                try self.vad.create(mode: .HighlyPermissive, delegate: self, frameWidth: c.frameWidth, sampleRate: c.sampleRate)
            } catch {
                assertionFailure("CoreMLWakewordRecognizer failed to create a valid VAD")
            }
            
            /// Signal normalization
            
            self.rmsTarget = c.rmsTarget
            self.rmsValue = self.rmsTarget
            self.rmsAlpha = c.rmsAlpha
            self.preEmphasis = c.preEmphasis
            
            /// Calculate stft/mel spectrogram configuration
            
            self.hopLength = c.fftHopLength * c.sampleRate / 1000
            let melLength: Int = c.melFrameLength * c.sampleRate / 1000 / self.hopLength
            self.melWidth = c.melFrameWidth
            
            /// Allocate the stft window and FFT/frame buffer
            
            self.fftWindow = SignalProcessing.fftWindowDispatch(windowType: c.fftWindowType, windowLength: c.fftWindowSize)
            self.fft = FFT(c.fftWindowSize)
            self.fftFrame = Array(repeating: 0.0, count: c.fftWindowSize)
            
            /// Calculate smoothing & phrasing window lengths
            
            let smoothLength: Int = c.wakeSmoothLength * c.sampleRate / 1000 / self.hopLength
            let phraseLength: Int = c.wakePhraseLength * c.sampleRate / 1000 / self.hopLength

            /// Allocate the buffers used for posterior smoothing
            /// and argmax used for phrasing, so that we don't do
            /// any allocation within the frame loop
            
            self.phraseSum = Array(repeating: 0.0, count: self.words.count)
            self.phraseMax = Array(repeating: 0.0, count: self.words.count)
            self.phraseArg = Array(repeating: 0, count: phraseLength)
            
            /// Allocate sliding window buffers
            
            self.sampleWindow = RingBuffer(c.fftWindowSize, repeating: 0.0)
            self.frameWindow = RingBuffer(melLength * self.melWidth, repeating: 0.0)
            self.smoothWindow = RingBuffer(smoothLength * self.words.count, repeating: 0.0)
            self.phraseWindow = RingBuffer(phraseLength * self.words.count, repeating: 0.0)
            
            /// Fill buffers (except samples) with zero to
            /// minimize detection delay caused by buffering
            
            self.frameWindow.fill(0)
            self.smoothWindow.fill(0)
            self.phraseWindow.fill(0)
            
            /// Calculate the wakeword activation lengths

            let frameWidth: Int = c.frameWidth
            self.minActive = c.wakeActiveMin / frameWidth
            self.maxActive = c.wakeActiveMax / frameWidth
        }
    }
    
    private func validateConfiguration() -> Void {
        if let c = self.configuration {
            /// Validate stft/mel spectrogram configuration
            let windowSize: Int = c.fftWindowSize
            if windowSize % 2 != 0 {
                assertionFailure("CoreMLWakewordRecognizer validateConfiguration invalid fft-window-size")
                return
            }

            /// Smoothing window capacity
            Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "smoothWindow capacity inital \(self.smoothWindow.capacity)", delegate: self.delegate, caller: self)
        }
    }
    
    // MARK: Audio processing
    
    private func process(_ data: Data, isSpeech: Bool) -> Void {
        self.activeLength += 1
        if self.context.isSpeech && self.activeLength < self.maxActive {
            /// Run the current frame through the detector pipeline.
            /// Activate the pipeline if a keyword phrase was detected.
            self.sample(data)
        } else {
            /// Continue this wakeword (or external) activation
            /// for at least the minimum, until a vad deactivation or timeout
            if (self.activeLength > self.minActive) && (!self.context.isSpeech || (self.activeLength >= self.maxActive)) {
                self.deactivatePipeline()
                self.reset()
                self.activeLength = 0
            }
        }
        
        /// Always clear detector state on a vad deactivation
        /// this prevents <keyword1><pause><keyword2> detection
        if !self.context.isSpeech {
            self.reset()
        }
    }
    
    private func sample(_ data: Data) -> Void {
        /// Preallocate an array of data elements in the frame for use in RMS and sampling
        let dataElements: Array<Int16> = data.elements()
        
        /// Update the rms normalization factors
        /// Maintain an ewma of the rms signal energy for speech samples
        if (self.context.isSpeech && self.rmsAlpha > 0) {
            self.rmsValue = self.rmsAlpha * SignalProcessing.rms(data, dataElements) + (1 - self.rmsAlpha) * self.rmsValue
        }
        
        /// Process all samples in the frame
        for d in dataElements {
            
            /// Normalize and clip the 16-bit sample to the target rms energy
            var sample: Float = Float(d) / Float(Int16.max)
            sample = sample * (self.rmsTarget / self.rmsValue)
            sample = max(-1.0, min(sample, 1.0))
            
            /// Run a pre-emphasis filter to balance high frequencies
            /// and eliminate any dc energy
            let currentSample: Float = sample
            sample -= self.preEmphasis * self.prevSample
            self.prevSample = currentSample
            
            if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
              self.sampleCollector?.append(sample)
            }
            /// Process the sample
            /// - write it to the sample sliding window
            /// - run the remainder of the detection pipleline if speech
            /// - advance the sample sliding window
            do {
                try self.sampleWindow.write(sample)
            } catch SpeechPipelineError.illegalState(let message) {
                fatalError("CoreMLWakewordRecognizer sample illegal state error \(message)")
            } catch let error {
                fatalError("CoreMLWakewordRecognizer sample unknown error occurred while processing \(error.localizedDescription)")
            }
            if self.sampleWindow.isFull {
                self.analyze()
                self.sampleWindow.rewind().seek(self.hopLength)
            }
        }
    }
    
    private func analyze() -> Void {
        /// The current sample window contains speech, so
        /// apply the fft windowing function to it
        for (index, _) in self.fftFrame.enumerated() {
            do {
                let sample: Float = try self.sampleWindow.read()
                self.fftFrame[index] = sample * self.fftWindow[index]
            } catch SpeechPipelineError.illegalState(let message) {
                fatalError("CoreMLWakewordRecognizer analyze illegal state error \(message)")
            } catch let error {
                fatalError("CoreMLWakewordRecognizer analyze unknown error occurred \(error.localizedDescription)")
            }
        }
        
        /// Compute the stft
        self.fft.forward(&self.fftFrame)
        
        if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
            self.fftFrameCollector? += "\(self.fftFrame)\n"
        }
        
        /// Decode the FFT outputs into the filter model's input
        self.filter()
    }
    
    private func reset() -> Void {
        /// Empty the sample buffer, so that only contiguous
        /// speech samples are written to it
        self.sampleWindow.reset()
        
        /// Reset and fill the other buffers,
        /// which prevents them from lagging the detection
        self.frameWindow.reset().fill(0)
        self.smoothWindow.reset().fill(0)
        self.phraseWindow.reset().fill(0)
        self.phraseMax = Array(repeating: 0.0, count: self.words.count)
    }
    
    private func activatePipeline() -> Void {
        if !self.context.isActive {
            self.context.isActive = true
            self.activeLength = 1
            self.deactivate()
            self.stopStreaming(context: self.context)
            self.delegate?.activate()
        }
    }
    
    private func deactivatePipeline() -> Void {
        if self.context.isActive {
            self.context.isActive = false
            self.stopStreaming(context: self.context)
            self.activeLength = 0
            self.delegate?.deactivate()
        }
    }
}

// MARK: CoreML filter and detect model predictions
extension CoreMLWakewordRecognizer {
    
    private func filter() -> Void {
        precondition(!self.fftFrame.isEmpty, "CoreMLWakewordRecognizer filter FFT Frame can't be empty")

        /// Cast the fftFrame single-dimension array of stft values into the model's required MLMultiArray data structure
        /// TODO: no need to decode fft outputs for model input?
        let frameCount: Int = (self.fftFrame.count / 2) + 1
        guard let multiArray = try? MLMultiArray(shape: [257,1,1], dataType: .float32) else {
            fatalError("CoreMLWakewordRecognizer filter unexpected runtime error allocating a MLMultiArray")
        }
        for i in 0..<frameCount {
            let floatValue: Float = self.fftFrame[i]
            let v: NSNumber = NSNumber(value: floatValue) // TODO: fftFrame is float. multiArray is float. why cast to NSNumber?
            multiArray[i] = v
        }

        do {
            /// execute the mel filterbank tensorflow model, gather predictions
            let options: MLPredictionOptions = MLPredictionOptions()
            options.usesCPUOnly = true // TODO: use GPU?
            let input: FilterInput = FilterInput(linspec_inputs__0: multiArray)
            let predictions: FilterOutput = try self.filterModel!.prediction(input: input, options: options)

            /// Copy the current mel frame into the mel window
            self.frameWindow.rewind().seek(self.melWidth)
            for i in 0..<predictions.melspec_outputs__0.shape[2].intValue {
                try? self.frameWindow.write(predictions.melspec_outputs__0[i].floatValue)
                if self.traceLevel.rawValue < Trace.Level.PERF.rawValue { filterCollector?.append(predictions.melspec_outputs__0[i].floatValue)
                }
            }

            /// Detect
            self.detect()

        } catch let modelFilterError {
            fatalError("CoreMLWakewordRecognizer filters failed to write predictions to framewindow due to \(modelFilterError)")
        }
    }
    
    private func detect() -> Void {
        guard let multiArray = try? MLMultiArray(shape: [1,40,40], dataType: .float32) else {
            fatalError("CoreMLWakewordRecognizer detect could not allocate a properly-shaped MLMultiArray")
        }
        
        /// transfer the mel filterbank window to the detector model's inputs
        self.frameWindow.rewind()
        var frameWindowIndex: Int = 0
        while !self.frameWindow.isEmpty {
            do {
                multiArray[frameWindowIndex] = NSNumber(value: try self.frameWindow.read())
            } catch let readException {
                fatalError("CoreMLWakewordRecognizer detect error reading the framewindow \(String(describing: self.frameWindow)) with exception\(readException)")
            }
            frameWindowIndex += 1
        }
        
        do {
            // run the classifier tensorflow model
            let options: MLPredictionOptions = MLPredictionOptions()
            options.usesCPUOnly = true // TODO: use GPU?
            let input: DetectInput = DetectInput(melspec_inputs__0: multiArray)
            let predictions: DetectOutput = try self.detectModel!.prediction(input: input, options: options)
            
            /// Transfer the classifier's outputs to the posterior smoothing window
            self.smoothWindow.rewind().seek(self.words.count)
            for index:Int in 0..<predictions.detect_outputs__0.count {
                let predictionFloat: Float = predictions.detect_outputs__0[index].floatValue
                do {
                    try self.smoothWindow.write(predictionFloat)
                } catch RingBufferStateError.illegalState(let message) {
                    fatalError(" CoreMLWakewordRecognizer detect Ringbuffer in an illegal state \(message)")
                } catch {
                    fatalError("CoreMLWakewordRecognizer detect couldn't write to smooth window")
                }
            }
            
            if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
                detectCollector? += "\(predictions.detect_outputs__0.debugDescription)\n"
            }

            /// send the prediction posteriors through a smoothing window
            self.smooth()
            
        } catch let modelDetectError {
            fatalError("CoreMLWakewordRecognizer detect error \(modelDetectError)")
        }
    }
}

// MARK: Posterior smoothing algorithms
extension CoreMLWakewordRecognizer {
    
    private func smooth() -> Void {
        /// Sum the per-class posteriors across the smoothing window
        for (index, _) in self.words.enumerated() {
            self.phraseSum[index] = 0
        }
        while !self.smoothWindow.isEmpty {
            for (index, _) in self.words.enumerated() {
                do {
                    self.phraseSum[index] += try self.smoothWindow.read()
                } catch RingBufferStateError.illegalState(let message) {
                    fatalError("CoreMLWakewordRecognizer smooth couldn't read the smoothing window: \(message)")
                } catch let error {
                    fatalError("CoreMLWakewordRecognizer smooth error \(error.localizedDescription)")
                }
            }
        }
        
        /// Compute the posterior mean of each keyword class
        /// Write the outputs to the phrasing window
        let total: Int = self.smoothWindow.capacity / self.words.count
        self.phraseWindow.rewind().seek(self.words.count)
        for (index, _) in self.words.enumerated() {
            do {
                let windowValue: Float = self.phraseSum[index] / Float(total)
                try self.phraseWindow.write(windowValue)
            } catch RingBufferStateError.illegalState(let message) {
                fatalError("CoreMLWakewordRecognizer smooth couldn't write to phrase window \(message)")
            } catch let error {
                fatalError("CoreMLWakewordRecognizer smooth error \(error.localizedDescription)")
            }
        }
        
        /// Activate the pipeline if the phrase window argmaxes match
        self.phrase()
    }
    
    private func phrase() -> Void {
        /// Compute the argmax (winning class) of each smoothed output
        /// in the current phrase window
        var i: Int = 0
        while !self.phraseWindow.isEmpty  {
            var argmax: Float = -Float.greatestFiniteMagnitude
            for (j, _) in self.words.enumerated() {
                do {
                    let value: Float = try self.phraseWindow.read()
                    self.phraseMax[j] = max(value, self.phraseMax[j])
                    if value > argmax {
                        self.phraseArg[i] = j
                        argmax = value
                    }
                } catch RingBufferStateError.illegalState(let message) {
                    fatalError("CoreMLWakewordRecognizer phrase couldn't read the phrase window \(message)")
                } catch let error {
                    fatalError("CoreMLWakewordRecognizer phrase error \(error.localizedDescription)")
                }
            }
            i += 1
        }
        
        /// Attempt to find a matching phrase amoung the argmaxes
        for phrase in self.phrases {
            /// Search for any occurrences of the phrase's keywords in order
            /// across the whole phrase window
            var match: Int = 0
            for word in self.phraseArg {
                if word == phrase[match] {
                    match += 1
                    if match == phrase.count {
                        break
                    }
                }
            }
            /// If we reached the end of a phrase, we have a match,
            /// so signal an activation
            if match == phrase.count {
                self.activatePipeline()
                break
            }
        }
        Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration?.tracing ?? Trace.Level.NONE, message: "words to maxes: \n\(self.words)\n\(self.phraseMax)", delegate: self.delegate, caller: self)
    }
    
    private func debug() -> Void {
        if self.traceLevel.rawValue <= Trace.Level.DEBUG.rawValue {
            Trace.spit(data: sampleCollector!.withUnsafeBufferPointer {Data(buffer: $0)}, fileName: "samples.txt", delegate: self.delegate!)
            Trace.spit(data: "[\((sampleCollector! as NSArray).componentsJoined(by: ", "))]".data(using: .utf8)!, fileName: "samples.txt", delegate: self.delegate!)
            Trace.spit(data: fftFrameCollector!.data(using: .utf8)!, fileName: "fftFrame.txt", delegate: self.delegate!)
            Trace.spit(data: "[\((filterCollector! as NSArray).componentsJoined(by: ", "))]".data(using: .utf8)!, fileName: "filterPredictions.txt", delegate: self.delegate!)
            Trace.spit(data: detectCollector!.data(using: .utf8)!, fileName: "detectPredictions.txt", delegate: self.delegate!)
        }
    }
}

// MARK: SpeechProcessor implementation

extension CoreMLWakewordRecognizer: SpeechProcessor {

    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    /// - Parameter context: The current speech context.
    public func startStreaming(context: SpeechContext) -> Void {
        AudioController.sharedInstance.delegate = self
        self.context = context
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    /// - Parameter context: The current speech context.
    public func stopStreaming(context: SpeechContext) -> Void {
        AudioController.sharedInstance.delegate = nil
        self.context = context
    }
}

// MARK: AudioControllerDelegate implementation

extension CoreMLWakewordRecognizer: AudioControllerDelegate {
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    ///
    /// Processes audio in an async thread.
    /// - Parameter frame: Frame of audio samples.
    func process(_ frame: Data) -> Void {
        /// multiplex the audio frame data to both the vad and, if activated, the model pipelines
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            do { try strongSelf.vad.process(frame: frame, isSpeech:
                strongSelf.context.isSpeech)
            } catch let error {
                strongSelf.delegate?.didError(error)
            }
            if strongSelf.context.isSpeech {
                strongSelf.process(frame, isSpeech: strongSelf.context.isSpeech)
            }
        }
    }
}

// MARK: VADDelegate implementation

extension CoreMLWakewordRecognizer: VADDelegate {
    
    /// Called when the VAD has detected speech.
    /// - Parameter frame: The first frame of audio samples with speech detected in it.
    public func activate(frame: Data) {
        /// activate the speech context
        self.context.isSpeech = true
        /// process the first frames of speech data from the vad
        self.process(frame, isSpeech: true)
    }
    
    /// Called when the VAD has stopped detecting speech.
    public func deactivate() {
        if self.activeLength >= self.maxActive {
            self.context.isSpeech = false
            self.debug()
        }
    }
}
