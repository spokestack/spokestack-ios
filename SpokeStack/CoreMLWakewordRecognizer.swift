//
//  CoreMLWakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 6/6/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CoreML
import Speech

public class CoreMLWakewordRecognizer: NSObject, WakewordRecognizerService {
    
    // MARK: Public (properties)
    
    static let sharedInstance: CoreMLWakewordRecognizer = CoreMLWakewordRecognizer()
    
    public var configuration: WakewordConfiguration? = WakewordConfiguration() {
        didSet {
            if configuration != nil {
                self.parseConfiguration()
                self.setConfiguration()
                self.validateConfiguration()
            }
        }
    }
    
    public weak var delegate: WakewordRecognizer?
    
    // MARK: Private (properties)

    enum FFTWindowType: String {
        case hann
    }
    
    private var vad: WITVad = WITVad()
    private var context: SpeechContext = SpeechContext()
    
    lazy private var wwfilter: WakeWordFilter = {
        return WakeWordFilter()
    }()

    lazy private var wwdetect: WakeWordDetect = {
        return WakeWordDetect()
    }()
    
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
    
    private var sampleWindow: RingBuffer!
    private var frameWindow: RingBuffer!
    private var smoothWindow: RingBuffer!
    private var phraseWindow: RingBuffer!

    /// Wakeword Activation Management
    
    private var minActive: Int = 0
    private var maxActive: Int = 0
    private var activeLength: Int = 0
    
    /// Debugging collectors
    
    private var sampleCollector: Array<Float> = []
    private var fftFrameCollector: String = ""
    private var filterCollector: Array<Float> = []
    private var detectCollector: String = ""
    
    // MARK: NSObject methods

    deinit {
        print("CoreMLWakewordRecognizer deinit")
        vad.delegate = nil
    }
    
    public override init() {
        super.init()
        print("CoreMLWakewordRecognizer init")
        self.vad.delegate = self
    }
    
    // MARK: SpeechRecognizerService implementation

    func startStreaming(context: SpeechContext) -> Void {
        print("CoreMLWakewordRecognizer startStreaming")
        AudioController.shared.delegate = self
        self.context = context
    }
    
    func stopStreaming(context: SpeechContext) -> Void {
        print("CoreMLWakewordRecognizer stopStreaming")
        AudioController.shared.delegate = nil
        self.context = context
    }
    
    // MARK: Private functions
    
    /// MARK: Configuration processing
    
    private func parseConfiguration() -> Void {
        if let c = self.configuration {

            /// Parse the list of keywords.
            /// Reserve the 0th index in words for the non-keyword class.
            let wakeWords: Array<String> = c.wakeWords.components(separatedBy: ",")
            self.words = Array(repeating: "", count: wakeWords.count +  1)
            for (index, _) in self.words.enumerated() {
                let indexOffset: Int = index + 1
                if indexOffset < self.words.count {
                    self.words[indexOffset] = wakeWords[indexOffset - 1]
                }
            }

            /// Parse the keyword phrases
            let wakePhrases: Array<String> = c.wakePhrases.components(separatedBy: ",")
            self.phrases = Array<Array<Int>>.init(repeating: [0], count: wakePhrases.count)
            for (i, phrase) in wakePhrases.enumerated() {
                let wakePhraseArray: Array<String> = phrase.components(separatedBy: " ")
                print("CoreMLWakewordRecognizer parseConfiguration wakePhraseArray \(wakePhraseArray)")
                /// Allocate an additional (null) slot at the end of each phrase,
                /// which forces the phraser to continue detection until the end
                /// of the final keyword in each phrase
                self.phrases[i] = Array<Int>.init(repeating: 0, count: wakePhrases.count + 1)
                for (j, keyword) in wakePhraseArray.enumerated() {
                    // verify that each keyword in the phrase is a known keyword
                    guard let k: Int = wakeWords.index(of: keyword) else {
                        assertionFailure("CoreMLWakewordRecognizer parseConfiguration wakeWords did not contain \(keyword)")
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
    
    private func setConfiguration() -> Void {
        
        if let c = self.configuration {
            let buffer: TimeInterval = TimeInterval((c.sampleRate / 1000) * c.frameWidth)
            AudioController.shared.sampleRate = c.sampleRate
            AudioController.shared.bufferDuration = buffer
        
            /// Signal normalization
            
            self.rmsTarget = c.rmsTarget
            self.rmsValue = self.rmsTarget
            self.rmsAlpha = c.rmsAlpha
            self.preEmphasis = c.preEmphasis
            
            /// Calculate stft/mel spectrogram configuration
            
            let sampleRate: Int = c.sampleRate
            self.hopLength = c.fftHopLength * sampleRate / 1000
            let melLength: Int = c.melFrameLength * sampleRate / 1000 / self.hopLength
            self.melWidth = c.melFrameWidth
            
            /// Allocate the stft window and FFT/frame buffer
            
            self.fftWindow = self.hannWindow(c.fftWindowSize)
            self.fft = FFT(c.fftWindowSize)
            self.fftFrame = Array(repeating: 0.0, count: c.fftWindowSize)
            
            /// Calculate smoothing & phrasing window lengths
            
            let smoothLength: Int = c.wakeSmoothLength * sampleRate / 1000 / self.hopLength
            let phraseLength: Int = c.wakePhraseLength * sampleRate / 1000 / self.hopLength

            /// Allocate the buffers used for posterior smoothing
            /// and argmax used for phrasing, so that we don't do
            /// any allocation within the frame loop
            
            self.phraseSum = Array(repeating: 0.0, count: self.words.count)
            self.phraseMax = Array(repeating: 0.0, count: self.words.count)
            self.phraseArg = Array(repeating: 0, count: phraseLength)
            
            /// Allocate sliding window buffers
            
            self.sampleWindow = RingBuffer(c.fftWindowSize)
            self.frameWindow = RingBuffer(melLength * self.melWidth)
            self.smoothWindow = RingBuffer(smoothLength * self.words.count)
            self.phraseWindow = RingBuffer(phraseLength * self.words.count)
            
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
            let windowType: String = c.fftWindowType
            guard windowType == FFTWindowType.hann.rawValue else {
                assertionFailure("CoreMLWakewordRecognizer validateConfiguration invalid fft-window-type")
                return
            }

            /// Smoothing window capacity
            print("CoreMLWakewordRecognizer validateConfiguration smoothWindow capacity inital \(self.smoothWindow.capacity)")
        }
    }
    
    /// MARK: Audio processing
    
    private func process(_ data: Data) -> Void {
        if !self.context.isActive {
            /// Run the current frame through the detector pipeline.
            /// Activate the pipeline if a keyword phrase was detected.
            self.sample(data)
        } else {
            /// Continue this wakeword (or external) activation
            /// for at least the minimum, until a vad deactivation or timeout
            self.activeLength += 1
            if (self.activeLength > self.minActive) && (!self.context.isSpeech || (self.activeLength > self.maxActive)) {
                self.deactivatePipeline()
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
            self.rmsValue = self.rmsAlpha * self.rms(data, dataElements) + (1 - self.rmsAlpha) * self.rmsValue
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
            
            sampleCollector.append(sample)
            
            /// Process the sample
            /// - write it to the sample sliding window
            /// - run the remainder of the detection pipleline if speech
            /// - advance the sample sliding window
            do {
                try self.sampleWindow.write(sample)
            } catch SpeechPipelineError.illegalState(let message) {
                fatalError("CoreMLWakewordRecognizer sample illegal state error \(message)")
            } catch {
                fatalError("CoreMLWakewordRecognizer sample unknown error occurred while processing \(#line)")
            }
            if self.sampleWindow.isFull {
                if (self.context.isSpeech) {
                    self.analyze()
                }
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
                print("CoreMLWakewordRecognizer analyze illegal state error \(message)")
            } catch {
                fatalError("CoreMLWakewordRecognizer analyze unknown error occurred \(#line)")
            }
        }
        
        /// Compute the stft
        self.fft.forward(&self.fftFrame)
        
        self.fftFrameCollector += "\(self.fftFrame)\n"
        
        /// Decode the FFT outputs into the filter model's input
        self.filter()
    }
    
    private func reset() -> Void {
        print("CoreMLWakewordRecognizer reset")
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
            //  self.stopStreaming(context: self.speechContext) // TODO: necessary?
            self.delegate?.activate()
        }
    }
    
    private func deactivatePipeline() -> Void {
        if self.context.isActive {
            self.context.isActive = false
            // self.stopStreaming(context: self.speechContext) // TODO: necessary?
            self.activeLength = 0
            self.delegate?.deactivate()
        }
    }
}

// MARK: Root Mean Squared and Hann algorithms

extension CoreMLWakewordRecognizer {
    private func rms(_ data: Data, _ dataElements: Array<Int16>) -> Float {
        var sum: Float = 0
        
        /// Process all samples in the frame
        /// calculating the sum of the squares of the samples
        for d in dataElements {
            let sample: Float = Float(d) / Float(Int16.max)
            sum += sample * sample
        }
        
        /// calculate rms
        return Float(sqrt(sum / Float(dataElements.count)))
    }
    
    private func hannWindow(_ length: Int) -> Array<Float> {
        /// https://en.wikipedia.org/wiki/Hann_function
        var window: Array<Float> = Array(repeating: 0, count: length)
        for (index, _) in window.enumerated() {
            window[index] = Float(pow(sin((Float.pi * Float(index)) / Float((length - 1))), 2))
        }
        return window
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
            let input: WakeWordFilterInput = WakeWordFilterInput(linspec_inputs__0: multiArray)
            let predictions: WakeWordFilterOutput = try self.wwfilter.prediction(input: input, options: options)
            
            /// Copy the current mel frame into the mel window
            self.frameWindow.rewind().seek(self.melWidth)
            for i in 0..<predictions.melspec_outputs__0.shape[2].intValue {
                try? self.frameWindow.write(predictions.melspec_outputs__0[i].floatValue)
                filterCollector.append(predictions.melspec_outputs__0[i].floatValue)
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
            let input: WakeWordDetectInput = WakeWordDetectInput(melspec_inputs__0: multiArray)
            let predictions: WakeWordDetectOutput = try self.wwdetect.prediction(input: input, options: options)
            
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
            
            detectCollector += "\(predictions.detect_outputs__0.debugDescription)\n"

            /// send the prediction posteriors through a smoothing window
            self.smooth()
            
        } catch let modelDetectError {
            fatalError("CoreMLWakewordRecognizer detect error \(modelDetectError)")
        }
    }
}

// Mark: Posterior smoothing algorithms
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
                } catch SpeechPipelineError.illegalState(let message) {
                    fatalError("CoreMLWakewordRecognizer smooth couldn't read the smoothing window: \(message)")
                } catch {
                    fatalError("CoreMLWakewordRecognizer smooth error \(#line)")
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
            } catch SpeechPipelineError.illegalState(let message) {
                fatalError("CoreMLWakewordRecognizer smooth couldn't write to phrase window \(message)")
            } catch {
                fatalError("CoreMLWakewordRecognizer smooth error \(#line)")
            }
        }
        
        /// Activate the pipeline if the phrase window argmaxes match
        self.phrase()
    }
    
    private func phrase() -> Void {
        
        /// Compute the argmax (winning class) of each smoothed output
        /// in the current phrase window
        var i: Int = 0
        while !self.phraseWindow.isEmpty {
            var argmax: Float = -Float.greatestFiniteMagnitude
            for (j, _) in self.words.enumerated() {
                do {
                    let value: Float = try self.phraseWindow.read()
                    self.phraseMax[j] = max(value, self.phraseMax[j])
                    if value > argmax {
                        self.phraseArg[i] = j
                        argmax = value
                    }
                } catch SpeechPipelineError.illegalState(let message) {
                    fatalError("CoreMLWakewordRecognizer phrase couldn't read the phrase window \(message)")
                } catch {
                    fatalError("CoreMLWakewordRecognizer phrase error \(#line)")
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
    }
}

extension CoreMLWakewordRecognizer: AudioControllerDelegate {
    func processSampleData(_ data: Data) -> Void {
        /// multiplex the audio frame data to both the vad and, if activated, the model pipelines
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.vad.vadSpeechFrame(data)
        }
        if self.context.isSpeech {
            audioProcessingQueue.async {[weak self] in
                guard let strongSelf = self else { return }
                strongSelf.process(data)
            }
        }
    }
}

extension CoreMLWakewordRecognizer: WITVadDelegate {
    
    public func activate(_ audioData: Data) {
        /// activate the speech context
        print("CoreMLWakewordRecognizer activate")
        self.context.isSpeech = true
        /// process the first frames of speech data from the vad
        self.process(audioData)
    }
    
    public func deactivate() {
        print("CoreMLWakewordRecognizer deactivate")
        self.context.isSpeech = false
        //self.spit(data: sampleCollector.withUnsafeBufferPointer {Data(buffer: $0)}, fileName: "samples.txt")
        //self.spit(data: fftFrameCollector.data(using: .utf8)!, fileName: "fftFrame.txt")
        //self.spit(data: filterCollector.withUnsafeBufferPointer {Data(buffer: $0)}, fileName: "filterPredictions.txt")
        //self.spit(data: detectCollector.data(using: .utf8)!, fileName: "detectPredictions.txt")
    }
    
    private func spit(data: Data, fileName: String) {
        let filemgr = FileManager.default
        if let path = filemgr.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last?.appendingPathComponent(fileName) {
            if !filemgr.fileExists(atPath: path.path) {
                filemgr.createFile(atPath: path.path, contents: data, attributes: nil)
                print("CoreMLWakewordRecognizer spit created \(data.count) fileURL: \(path.path)")
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.write(data)
                    handle.synchronizeFile()
                } catch let error {
                    print("CoreMLWakewordRecognizer spit failed to open a handle to \(path.path) because \(error)")
                }
            } else {
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.synchronizeFile()
                    print("CoreMLWakewordRecognizer spit appended \(data.count) to: \(path.path)")
                } catch let error {
                    print("CoreMLWakewordRecognizer spit failed to open a handle to \(path.path) because \(error)")
                }
            }
        } else {
            print("CoreMLWakewordRecognizer spit failed to get a URL for \(fileName)")
        }
    }
}
