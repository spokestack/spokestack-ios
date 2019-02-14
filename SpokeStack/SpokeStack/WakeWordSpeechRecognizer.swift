//
//  WakeWordController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CoreML
import Speech

public class WakeWordSpeechRecognizer: NSObject, WakewordRecognizerService {

    // MARK: Public (properties)
    
    static let sharedInstance: WakeWordSpeechRecognizer = WakeWordSpeechRecognizer()
    
    // MARK: SpeechRecognizerService (properties)

    public var configuration: WakewordConfiguration = WakewordConfiguration()
    
    public weak var delegate: WakewordRecognizer?
    
    // MARK: Internal (properties)
    
    enum FFTWindowType: String {
        case hann
    }
    
    // MARK: Private (properties)
    
    private var wwfilter: WakeWordFilter = WakeWordFilter()
    
    private var wwdetect: WakeWordDetect = WakeWordDetect()
    
    private var dispatchWorker: DispatchWorkItem?
    
    private var speechContext: SpeechContext?
    
    /// Keyword / phrase configuration and preallocated buffers
    
    private var words: Array<String> = []
    
    private var phrases: TwoDimensionArray<Int> = [[Int]]()
    
    private var phraseSum: Array<Float> = []
    
    private var phraseArg: Array<Int> = []
    
    private var phraseMax: Array<Float> = []
    
    /// Audio Signal Normalization
    
    private var rmsTarget: Float = 0.0
    
    private var rmsAlpha: Float = 0.0
    
    private var rmsValue: Float = 0.0
    
    private var preEmphasis: Float = 0.0
    
    private var prevSample: Float = 0.0
    
    /// STFL / MEL Filterbank Configuration
    
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
    
    private let audioController: AudioController = AudioController.shared
    
    // MARK: Initializers
    
    deinit {
        audioController.delegate = nil
        speechContext = nil
    }
    
    public override init() {
        
        super.init()
        self.setup()
    }
    
    // MARK: Internal (methods)
    
    func startStreaming(context: SpeechContext) -> Void {
        
        self.speechContext = context
        
        /// Automatically restart wakeword task if it goes over Apple's 1
        /// minute listening limit
        
        self.dispatchWorker = DispatchWorkItem {
            self.stopStreaming(context: context)
            self.startStreaming(context: context)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.configuration.wakeActiveMax),
                                      execute: self.dispatchWorker!)
        
        /// Words and phrasing
        
        self.setupWordsAndPhrases()
        
        let buffer: TimeInterval = TimeInterval((self.configuration.sampleRate / 1000) * self.configuration.frameWidth)
        self.audioController.sampleRate = self.configuration.sampleRate
        self.audioController.bufferDuration = buffer
        self.audioController.delegate = self
        self.audioController.startStreaming()
    }
    
    func stopStreaming(context: SpeechContext) -> Void {
        
        self.audioController.delegate = nil
        self.audioController.stopStreaming()

        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }
    
    // MARK: Private (methods)
    
    private func setup() -> Void {
        
        /// Fetch signal normalization config
        
        self.rmsTarget = self.configuration.rmsTarget
        self.rmsAlpha = self.configuration.rmsAlpha
        self.rmsValue = self.rmsTarget
        self.preEmphasis = self.configuration.preEmphasis
        
        /// Fetch and validate stft/mel spectrogram configuration
        
        let sampleRate: Int = self.configuration.sampleRate
        let windowSize: Int = self.configuration.fftWindowSize
        self.hopLength = self.configuration.fftHopLength * sampleRate / 1000
        
        let windowType: String = self.configuration.fftWindowType
        
        if windowSize % 2 != 0 {
            
            assertionFailure("fft-window-size")
            return
        }
        
        let melLength: Int = self.configuration.melFrameLength * sampleRate / 1000 / self.hopLength
        self.melWidth = self.configuration.melFrameWidth
        
        /// Allocate the stft window and FFT/frame buffer
        
        guard windowType == FFTWindowType.hann.rawValue else {
            
            assertionFailure("fft-window-type")
            return
        }
        
        self.fftWindow = self.hannWindow(windowSize)
        self.fft = FFT(windowSize)
        self.fftFrame = Array(repeating: 0.0, count: windowSize)
        
        /// fetch smoothing/phrasing window lengths
        
        let smoothLength: Int = self.configuration.wakeSmoothLength * sampleRate / 1000 / self.hopLength
        let phraseLength: Int = self.configuration.wakePhraseLength * sampleRate / 1000 / self.hopLength
        
        /// Allocate sliding windows
        /// Fill all buffers (except samples) with zero, in order to
        /// Minimize detection delay caused by buffering
        
        self.sampleWindow = RingBuffer(windowSize)
        self.frameWindow = RingBuffer(melLength * self.melWidth)
        self.smoothWindow = RingBuffer(smoothLength * self.words.count)
        self.phraseWindow = RingBuffer(phraseLength * self.words.count)
        
        self.frameWindow.fill(0)
        self.smoothWindow.fill(0)
        self.phraseWindow.fill(0)
        
        /// Preallocate the buffers used for posterior smoothing
        /// and argmax used for phrasing, so that we don't do
        /// any allocation within the frame loop
        
        self.phraseSum = Array(repeating: 0.0, count: self.words.count)
        self.phraseMax = Array(repeating: 0.0, count: self.words.count)
        self.phraseArg = Array(repeating: 0, count: phraseLength)
        
        /// Configure the wakeword activation lengths
        
        let frameWidth: Int = self.configuration.frameWidth
        
        self.minActive = self.configuration.wakeActionMin / frameWidth
        self.maxActive = self.configuration.wakeActionMax / frameWidth
    }
    
    private func setupWordsAndPhrases() -> Void {
        
        /// Parse the configured list of keywords
        /// Allocate an additional slot for the non-keyword class at 0
        
        let wakeWords: Array<String> = self.configuration.wakeWords.components(separatedBy: ",")
        self.words = Array(repeating: "", count: wakeWords.count + 1)
        
        for (index, _) in self.words.enumerated() {
            
            let indexOffset: Int = index + 1
            
            if indexOffset < self.words.count {
                self.words[indexOffset] = wakeWords[indexOffset - 1]
            }
        }
        
        /// Parse the keyword phrase configuration
        
        var wakePhrases: Array<String> = self.configuration.wakePhrases.components(separatedBy: ",")
        self.phrases = TwoDimensionArray<Int>.init(repeating: [0], count: wakePhrases.count)
        
        for (index, _) in wakePhrases.enumerated() {
            
            let wakePhrase: String = wakePhrases[index]
            let wakePhraseArray: Array<String> = wakePhrase.components(separatedBy: " ")
            
            /// Allocate an additional (null) slot at the end of each phrase,
            /// which forces the phraser to continue detection until the end
            /// of the final keyword in each phrase
            
            self.phrases[index] = Array<Int>.init(repeating: 0, count: wakePhrases.count + 1)
            
            for (j, _) in wakePhraseArray.enumerated() {
                
                guard let k: Int = wakeWords.index(of: wakePhraseArray[j]) else {
                    
                    assertionFailure("wake-phrases")
                    return
                }
                
                if j < self.phrases[index].count {
                    self.phrases[index][j] = k + 1
                }
            }
        }
    }

    private func process(_ data: Data) -> Void {
        
        // TODO: Handle vad rise / fall
        // https://github.com/pylon/spokestack-android/blob/master/src/main/java/com/pylon/spokestack/wakeword/WakewordTrigger.java#L366
        
        guard let context: SpeechContext = self.speechContext else {
            self.delegate?.didError(SpeechPipelineError.illegalState("The speech context can't be nil"))
            return
        }

        if !context.isActive {
            
            /// Run the current frame through the detector pipeline
            /// activate if a keyword phrase was detected

            self.sample(data, context: context)

        } else {
            
            /// Continue this wakeword (or external) activation
            /// until a vad deactivation or timeout
            
            self.activeLength += 1
            
            if self.activeLength > self.minActive {
                
                if self.activeLength > self.maxActive {
                    self.deactivate(context)
                }
            }
        }
    }
    
    private func sample(_ data: Data, context: SpeechContext) -> Void {

        /// Update the rms normalization factors
        /// Maintain an ewma of the rms signal energy for speech samples
        
        // TODO: Need to verify that the audio "isSpeech"
        /// https://github.com/pylon/spokestack-android/blob/master/src/main/java/com/pylon/spokestack/wakeword/WakewordTrigger.java#L391
        if self.rmsAlpha > 0 {
            self.rmsValue = self.rmsAlpha * self.rms(data) + (1 - self.rmsAlpha) * self.rmsValue
        }

        /// Process all samples in the frame
        
        let dataElements: Array<Int16> = data.elements()
        var newDataIterator = dataElements.makeIterator()
        
        while let num = newDataIterator.next() {

            /// Normalize and clip the 16-bit sample to the target rms energy

            var sample: Float = Float(num) / Float(Int16.max)

            sample = sample * (self.rmsTarget / self.rmsValue)
            sample = max(-1.0, min(sample, 1.0))
            
            /// Run a pre-emphasis filter to balance high frequencies
            /// and eliminate any dc energy

            let nextSample: Float = sample
            sample -= self.preEmphasis * self.prevSample
            
            self.prevSample = nextSample

            /// Process the sample
            /// Write it to the sample sliding window
            /// run the remainder of the detection pipleline if speech
            /// advance the sample sliding window

            do {

                try self.sampleWindow.write(sample)

            } catch SpeechPipelineError.illegalState(let message) {

                fatalError("illegal state error \(message)")

            } catch {

                fatalError("Unknown Error Occurred while processing sample \(#line)")
            }

            if self.sampleWindow.isFull {
                
                // TODO: Check for "isSpeech" before analyze

                self.analyze(context)
                self.sampleWindow.rewind().seek(self.hopLength)
            }
        }
    }
    
    private func hannWindow(_ length: Int) -> Array<Float> {
        
        /// https://en.wikipedia.org/wiki/Hann_function
        
        var window: Array<Float> = Array(repeating: 0, count: length)
        
        for (index, _) in window.enumerated() {
            
            let base: Double = Double(sin((Float.pi * Float(index)) / Float((length - 1))))
            let exponent: Double = 2

            window[index] = Float(pow(base, exponent))
        }
        
        return window
    }

    private func rms(_ data: Data) -> Float {

        var sum: Float = 0
        var count: Int = 0

        /// Process all samples in the frame
        
        let dataElements: Array<Int16> = data.elements()
        var newDataIterator = dataElements.makeIterator()
        
        while let num = newDataIterator.next() {
            
            let sample: Float = Float(num) / Float(Int16.max)
            
            sum += sample * sample
            count += 1
        }

        let rms: Float = Float(sqrt(sum / Float(count)))
        return rms
    }
    
    private func reset() -> Void {
        
        /// Empty the sample buffer, so that only contiguous
        /// speech samples are written to it
        
        self.sampleWindow.reset()
        
        /// Reset and fill the other buffers,
        /// hich prevents them from lagging the detection
        
        self.frameWindow.reset().fill(0)
        self.smoothWindow.reset().fill(0)
        self.phraseWindow.reset().fill(0)
        self.phraseMax = Array(repeating: 0.0, count: self.words.count)
    }
    
    private func activate(_ context: SpeechContext) -> Void {
        
        if !context.isActive {
            
            context.isActive = true
            
            self.activeLength = 1
            self.delegate?.activate()
            
            self.dispatchWorker?.cancel()
            self.stopStreaming(context: context)
        }
    }
    
    private func deactivate(_ context: SpeechContext) -> Void {

        if context.isActive {
            
            context.isActive = false
            
            self.delegate?.deactivate()
            self.activeLength = 0
            
            self.dispatchWorker?.cancel()
            self.stopStreaming(context: context)
        }
    }
}

extension WakeWordSpeechRecognizer {
    
    private func analyze(_ context: SpeechContext) -> Void {

        /// Apply the windowing function to the current sample window
        
        for (index, _) in self.fftFrame.enumerated() {
            
            do {
                
                let sample: Float = try self.sampleWindow.read()
                self.fftFrame[index] = sample * self.fftWindow[index]
                
            } catch SpeechPipelineError.illegalState(let message) {
                
                print("illegal state error \(message)")
                
            } catch {
                
                fatalError("Unknown Error Occurred while analyzing \(#line)")
            }
        }
        
        /// Compute the stft

        self.fft.forward(&self.fftFrame)
        self.filter(context)
    }
    
    private func filter(_ context: SpeechContext) -> Void {
        
        precondition(!self.fftFrame.isEmpty, "FFT Frame can't be empty")

        /// Decode the FFT outputs into the filter model's input
        /// Compute the nagitude (abs) of each complex stft component
        /// The first and last stft components contain only real parts
        /// and are stored in the first of the first two positions of the stft
        /// output. The remaining components contact real / imaginary parts
        
        let frameCount: Int = (self.fftFrame.count / 2) + 1

        /// Run the predictions

        guard let multiArray = try? MLMultiArray(shape: [257,1,1], dataType: .float32) else {

                fatalError("Unexpected runtime error. MLMultiArray")
        }

        for i in 0..<frameCount {

            let floatValue: Float = self.fftFrame[i]
            multiArray[i] = NSNumber(value: floatValue)
        }

        do {

            let input: WakeWordFilterInput = WakeWordFilterInput(linspec_inputs__0: multiArray)
            let predictions: WakeWordFilterOutput = try self.wwfilter.prediction(input: input)

            /// Copy the current mel frame into the mel window

            self.frameWindow.rewind().seek(self.melWidth)

            for i in 0..<predictions.melspec_outputs__0.shape[2].intValue {
                try? self.frameWindow.write(predictions.melspec_outputs__0[i].floatValue)
            }

            /// Detect

            self.detect(context)

        } catch let modelFilterError {

            fatalError("modelFilterError is thrown \(modelFilterError)")
        }
    }
    
    private func detect(_ context: SpeechContext) -> Void {

        /// Transfer the mel filterbank window to the detector model's inputs
        
        self.frameWindow.rewind()
        
        guard let multiArray = try? MLMultiArray(shape: [1,40,40], dataType: .float32) else {
            
                fatalError("Unexpected runtime error. MLMultiArray")
        }
        
        var frameWindowIndex: Int = 0
        
        while !self.frameWindow.isEmpty {

            do {

                multiArray[frameWindowIndex] = NSNumber(value: try self.frameWindow.read())

            } catch let readException {

                fatalError("There is an error reading the framewindow \(String(describing: self.frameWindow)) and exception\(readException)")
            }

            frameWindowIndex += 1
        }
        
        /// Run against CoreML
        
        do {
            
            let input: WakeWordDetectInput = WakeWordDetectInput(melspec_inputs__0: multiArray)
            let predictions: WakeWordDetectOutput = try self.wwdetect.prediction(input: input)
            
            /// Transfer the classifier's outputs to the posterior smoothing window
            
            self.smoothWindow.rewind().seek(self.words.count)

            let resultCount: Int = predictions.detect_outputs__0.count
            var indexIncrement: Int = 0
            
            repeat {
                
                let predictionFloat: Float = predictions.detect_outputs__0[indexIncrement].floatValue

                do {
                    
                    try self.smoothWindow.write(predictionFloat)
                    
                } catch {
                  
                    fatalError("couldn't write the smooth window")
                }
                
                indexIncrement += 1

            } while indexIncrement < resultCount
            
        } catch let modelDetectError {
            
            fatalError("modelDetectError is thrown \(modelDetectError)")
        }
        
        self.smooth(context)
    }
}

extension WakeWordSpeechRecognizer {
    
    private func smooth(_ context: SpeechContext) -> Void {
        
        /// Sum the per-class posteriors across the smoothing window
        
        for (index, _) in self.words.enumerated() {
            self.phraseSum[index] = 0
        }

        while !self.smoothWindow.isEmpty {
            
            for (index, _) in self.words.enumerated() {
                
                do {

                    self.phraseSum[index] += try self.smoothWindow.read()

                } catch SpeechPipelineError.illegalState(let message) {
                    
                    fatalError("Error occured while smoothing \(message)")
                    
                } catch {
                    
                     fatalError("Error occured while smoothing \(#line)")
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
                
                fatalError("illegal state error \(message)")
                
            } catch {
                
                fatalError("Error occured while smoothing \(#line)")
            }
        }
        
        self.phrase(context)
    }
    
    private func phrase(_ context: SpeechContext) -> Void {
        
        /// Compute the argmax (winning class) of each smoothed output
        /// in the current phrase window
        
        var index: Int = 0
        
        repeat {
            
            var maxFloat: Float = -Float.greatestFiniteMagnitude
            
            for (subindex, _) in self.words.enumerated() {

                do {

                    let value: Float = try self.phraseWindow.read()
                    self.phraseMax[subindex] = max(value, self.phraseMax[subindex])
                    
                    if value > maxFloat {
                    
                        self.phraseArg[index] = subindex
                        maxFloat = value
                    }

                } catch SpeechPipelineError.illegalState(let message) {
                    
                    fatalError("illegal state error \(message)")
                    
                } catch {
                    
                    fatalError("Error occured while phrase \(#line)")
                }
            }

            index += 1

        } while !self.phraseWindow.isEmpty
        
        /// Attempt to find a matching phrase amoung the argmaxes
        
        phrasesArgumentLabel: for phrase in self.phrases {
            
            /// Search for any occurrences of the phrase's keywords in order
            /// across the whole phrase window
            
            var match: Int = 0
            
            phraseArgumentLabel: for word in self.phraseArg {
                
                if word == phrase[match] {
                    
                    match += 1
                    if match == phrase.count {
                       
                        print("match == phrase count \(match) and phrase \(phrase)")
                        break
                    }
                }
            }
            
            /// If we reached the end of a phrase, we have a match,
            /// So start the activation counter

            if match == phrase.count {
                print("match does == phrase count before activate")
                self.activate(context)
                break
            }
        }
    }
}

extension WakeWordSpeechRecognizer: AudioControllerDelegate {
    
    func didStart(_ engineController: AudioController) {
        print("audioEngine did start")
    }
    
    func didStop(_ engineController: AudioController) {
        print("audioEngine did stop")

        /// Reset
        
        self.reset()
    }
    
    func setupFailed(_ error: String) -> Void {
        fatalError(error)
    }
    
    func processSampleData(_ data: Data) -> Void {
        self.process(data)
    }
}
