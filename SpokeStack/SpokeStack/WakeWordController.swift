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

private struct ModelConstants {
    
    static let numOfBatches = 1
    
    static let numOfFrames = 1
    
    static let numOfFFTComponents = 257
}

class WakeWordController: NSObject {
    
    // MARK: Internal (properties)
    
    enum FFTWindowType: String {
        case hann
    }
    
    // MARK: Private (properties)
    
    private var audioData: NSMutableData!
    
    private var wwfilter: WakeWordFilter!
    
    private var wwdetect: WakeWordDetect!
    
    /// Keyword / phrase configuration and preallocated buffers
    
    private var words: Array<String> = []
    
    private var phrases: TwoDimensionArray<Int> = [[Int]]()
    
    private var phraseSum: Array<Float> = []
    
    private var phraseArg: Array<Int> = []
    
    /// Audio Signal Normalization
    
    private var rmsTarget: Float = 0.0
    
    private var rmsAlpha: Float = 0.0
    
    private var rmsValue: Float = 0.0
    
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
    
    private var wakeWordConfiguration: WakeRecognizerConfiguration!
    
//    private let audioEngineController: AudioEngineController
    
    ///
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    
    ///
    
    // MARK: Initializers
    
    deinit {
//        audioEngineController.delegate = nil
    }
    
    override init() {
        super.init()
    }
    
    required convenience init(_ configuration: WakeRecognizerConfiguration) {

//        let buffer: Int = (configuration.sampleRate / 1000) * configuration.frameWidth
//
//        self.audioEngineController = AudioEngineController(buffer)
//        self.audioEngineController.delegate = self
//
//        self.setup()
        self.init()
        self.wakeWordConfiguration = configuration
    }
    
    // MARK: Internal (methods)
    
    func activate() -> Void {
        
        if self.audioEngine.isRunning {
            self.audioEngine.stop()
        }
        
        self.recognitionTask?.cancel()
        let audioSession = AVAudioSession.sharedInstance()

        do {
            
            try audioSession.setCategory(.record, mode: .spokenAudio, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
//        self.audioData = NSMutableData()
//        try? self.audioEngineController.startRecording()
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        self.speechRecognizer.delegate = self

        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        self.speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
    }
    
    func deactivate() -> Void {
//        self.audioEngineController.stopRecording()
        recognitionRequest?.endAudio()
        speechRecognizer.delegate = nil
        audioEngine.stop()
    }
    
    // MARK: Private (methods)
    
    private func setup() -> Void {

        /// Parse the configured list of keywords
        /// Allocate an additional slot for the non-keyword class at 0
        
        let wakeWords: Array<String> = self.wakeWordConfiguration.wakeWords.components(separatedBy: ",")
        self.words = Array(repeating: "", count: wakeWords.count + 1)
        
        for (index, _) in self.words.enumerated() {
            
            let indexOffset: Int = index + 1
            
            if indexOffset < self.words.count {
                self.words[indexOffset] = wakeWords[indexOffset - 1]
            }
        }
        
        /// Parse the keyword phrase configuration
        
        var wakePhrases: Array<String> = self.wakeWordConfiguration.wakePhrases.components(separatedBy: ",")
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
        
        /// Fetch signal normalization config
        
        self.rmsTarget = self.wakeWordConfiguration.rmsTarget
        self.rmsAlpha = self.wakeWordConfiguration.rmsAlpha
        self.rmsValue = self.rmsTarget
        
        /// Fetch and validate stft/mel spectrogram configuration
        
        let sampleRate: Int = self.wakeWordConfiguration.sampleRate
        let windowSize: Int = self.wakeWordConfiguration.fftWindowSize
        self.hopLength = self.wakeWordConfiguration.fftHopLength * sampleRate / 1000
        
        let windowType: String = self.wakeWordConfiguration.fftWindowType
        
        if windowSize % 2 != 0 {
            
            assertionFailure("fft-window-size")
            return
        }
        
        let melLength: Int = self.wakeWordConfiguration.melFrameLength * sampleRate / 1000 / self.hopLength
        self.melWidth = self.wakeWordConfiguration.melFrameWidth
        
        /// Allocate the stft window and FFT/frame buffer
        
        guard windowType == FFTWindowType.hann.rawValue else {
            
            assertionFailure("fft-window-type")
            return
        }
        
        self.fftWindow = self.hannWindow(windowSize)
        self.fft = FFT(windowSize)
        self.fftFrame = Array(repeating: 0.0, count: windowSize)
        
        /// fetch smoothing/phrasing window lengths
        
        let smoothLength: Int = self.wakeWordConfiguration.wakeSmoothLength * sampleRate / 1000 / self.hopLength
        let phraseLength: Int = self.wakeWordConfiguration.wakePhraseLength * sampleRate / 1000 / self.hopLength
        
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
        self.phraseArg = Array(repeating: 0, count: phraseLength)
        
        /// Configure the wakeword activation lengths
        
        let frameWidth: Int = self.wakeWordConfiguration.frameWidth
        
        self.minActive = self.wakeWordConfiguration.wakeActionMin / frameWidth
        self.maxActive = self.wakeWordConfiguration.wakeActionMax / frameWidth
    }
    
    private func process(_ buffer: AVAudioPCMBuffer) -> Void {
        
        // TODO: Need to handle "state"
        //
        // See: https://github.com/pylon/spokestack-android/blob/a5b1e4cf194b10e209c1b740c2e9655989b24cb9/src/main/java/com/pylon/spokestack/wakeword/WakewordTrigger.java#L370
        
        self.sample(buffer.spstk_data, buffer: buffer)
    }
    
    private func sample(_ data: Data, buffer: AVAudioPCMBuffer) -> Void {

        /// Update the rms normalization factors
        /// Maintain an ewma of the rms signal energy for speech samples

        self.rmsValue = self.rmsAlpha * self.rms(buffer) + (1 - self.rmsAlpha) * self.rmsValue

        /// Process all samples in the frame
        
        let floats: Array<Float> = data.elements()
        var newDataIterator = floats.makeIterator()

        while let num = newDataIterator.next() {
            
//            let fraction = Float.random(in: 0 ..< 1)
//            print("what is the number from the sample \(num)")

            /// Normalize and clip the 16-bit sample to the target rms energy
            
            var sample: Float = num / Float(Int16.max)
            
            sample = sample * (self.rmsTarget / self.rmsValue)
            sample = max(-1.0, min(sample, 1.0))
            
            /// Process the sample
            /// Write it to the sample sliding window
            /// run the remainder of the detection pipleline if speech
            /// advance the sample sliding window
            
            print("what is the sample \(sample)")
            
            do {

                try self.sampleWindow.write(sample)
                
            } catch SpeechPipelineError.illegalState(let message) {
                
                print("illegal state error \(message)")
                
            } catch {
                
                print("Unknown Error Occurred while processing sample")
            }
            
            if self.sampleWindow.isFull {

                self.analyze()
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

    private func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        
        guard let channelData = buffer.floatChannelData else {
            return 0.0
        }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map{ channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map{ $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

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
    }
}

extension WakeWordController: SFSpeechRecognizerDelegate {
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("didChange \(available)")
    }
}

extension WakeWordController: SFSpeechRecognitionTaskDelegate {
    
    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionDidDetectSpeech \(task)")
    }
    
    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionTaskFinishedReadingAudio")
    }
    
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionTaskWasCancelled")
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        print("didFinishSuccessfully")
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didRecord audioPCMBuffer: AVAudioPCMBuffer) {
        print("didRecord \(audioPCMBuffer)")
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        print("didHypothesizeTranscription \(transcription.formattedString)")
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("didFinishRecognition \(recognitionResult.bestTranscription)")
    }
}

extension WakeWordController {
    
    private func analyze() -> Void {
        
        /// Apply the windowing function to the current sample window
        
        for (index, _) in self.fftFrame.enumerated() {
            
            do {
                
                self.fftFrame[index] = try self.sampleWindow.read() * self.fftWindow[index]
                
            } catch SpeechPipelineError.illegalState(let message) {
                
                print("illegal state error \(message)")
                
            } catch {
                
                print("Unknown Error Occurred while processing sample")
            }
        }
        
        /// Compute the stft
        
        self.fft.forward(self.fftFrame)
        self.filter()
    }
    
    private func filter() -> Void {
        
        print("do i ever hit the filter???? \(self.fftFrame) and count \(self.fftFrame.count)")

        self.wwfilter = WakeWordFilter()

        /// Decode the FFT outputs into the filter model's input
        /// Compute the nagitude (abs) of each complex stft component
        /// The first and last stft components contain only real parts
        /// and are stored in the first of the first two positions of the stft
        /// output. The remaining components contact real / imaginary parts
        
        var components: Array<Double> = Array<Double>.init(repeating: 0, count: ModelConstants.numOfFFTComponents)
        
        /// Populate the components
        
        let firstComponent: Double = Double(self.fftFrame.first!)
        components.append(firstComponent)
        
        var i: Int = 1
        repeat {
            
            let re: Float = self.fftFrame[i * 2 + 0]
            let im: Float = self.fftFrame[i * 2 + 1]
            let ab: Float = sqrt(re * re + im * im)
            
            components.append(Double(ab))
            
            i += 1
            
        } while i < (self.fftFrame.count / 2)
        
        let lastComponent: Double = Double(self.fftFrame[1])
        components.append(lastComponent)
        
        /// Run the predictions
        
        guard let multiArray = try? MLMultiArray(shape: [
            ModelConstants.numOfBatches,
            ModelConstants.numOfFrames,
            ModelConstants.numOfFFTComponents] as [NSNumber], dataType: .double) else {
                
                fatalError("Unexpected runtime error. MLMultiArray")
        }
        
        print("componentes in filter \(components)")
        for (index, value) in components.enumerated() {
            multiArray[[0, 0, index] as [NSNumber]] = value as NSNumber
        }
        
        print("what is my multiArray \(multiArray.strides)")
    
        do {
        
            let input: WakeWordFilterInput = WakeWordFilterInput(linspec_inputs__0: multiArray)
            let predictions: WakeWordFilterOutput = try self.wwfilter.prediction(input: input)
            
            /// Copy the current mel frame into the mel window
            
            self.frameWindow.rewind().seek(self.melWidth)
            
            for i in 0...40 {
                
                let result = String(describing: predictions.melspec_outputs__0[i])
                print("what is my result \(result)")
            }
            
            /// Detect
            
            self.detect()
            
        } catch let modelFilterError {
            
            print("modelFilterError is thrown \(modelFilterError)")
        }
    }
    
    private func detect() -> Void {

        /// Transfer the mel filterbank window to the detector model's inputs
        
        self.frameWindow.rewind()
        
        /// Setup CoreML

        self.wwdetect = WakeWordDetect()
        
        guard let multiArray = try? MLMultiArray(shape: [1, 40, 40] as [NSNumber], dataType: .double) else {
            fatalError("Unexpected runtime error. MLMultiArray")
        }
        
        for index in 0...40 {
            multiArray[[0, index, index] as [NSNumber]] = index as NSNumber
        }
        
        /// Run against CoreML
        
        do {
            
            let input: WakeWordDetectInput = WakeWordDetectInput(melspec_inputs__0: multiArray)
            let predictions: WakeWordDetectOutput = try self.wwdetect.prediction(input: input)
            
            for result in predictions.detect_outputs__0.strides {
                print("what is my output result \(result)")
            }
            
        } catch let modelFilterError {
            
            print("modelFilterError is thrown \(modelFilterError)")
        }
        
        /// Rransfer the classifier's outputs to the posterior smoothing window
        
//        // transfer the mel filterbank window to the detector model's inputs
//        this.frameWindow.rewind();
//        this.detectModel.inputs().rewind();
//        while (!this.frameWindow.isEmpty())
//        this.detectModel.inputs().putFloat(this.frameWindow.read());
//
//        // run the classifier tensorflow model
//        this.detectModel.run();
//
//        // transfer the classifier's outputs to the posterior smoothing window
//        this.smoothWindow.rewind().seek(this.words.length);
//        while (this.detectModel.outputs().hasRemaining())
//        this.smoothWindow.write(this.detectModel.outputs().getFloat());
//
//        smooth();
    }
}

extension WakeWordController: AudioEngineControllerDelegate {
    
    func didReceive(_ buffer: AVAudioPCMBuffer) {
        self.process(buffer)
    }
    
    func didStart(_ engineController: AudioEngineController) {
        print("it did start")
    }
    
    func didStop(_ engineController: AudioEngineController) {
        
        /// "close"
        
        /// Reset
        
        self.reset()
    }
}

extension WakeWordController {
    
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
                    print("illegal state error \(message)")
                } catch {
                    print("Unknown Error Occurred while processing sample")
                }
            }
        }
        
        /// Compute the posterior mean of each keyword class
        /// Write the outputs to the phrasing window
        
        let total: Int = self.smoothWindow.capacity / self.words.count
        self.phraseWindow.rewind().seek(self.words.count)

        for (index, _) in self.words.enumerated() {
            
            do {
                
                try self.phraseWindow.write(self.phraseSum[index] / Float(total))

            } catch SpeechPipelineError.illegalState(let message) {
                print("illegal state error \(message)")
            } catch {
                print("Unknown Error Occurred while processing sample")
            }
        }
        
        self.phrase()
    }
    
    private func phrase() -> Void {
        
        /// Compute the argmax (winning class) of each smoothed output
        /// in the current phrase window
        
        var index: Int = 0
        var max: Float = -Float.greatestFiniteMagnitude
        
        repeat {
            
            for (subindex, _) in self.words.enumerated() {

                do {

                    let value: Float = try self.phraseWindow.read()
                    if value > max {
                        self.phraseArg[index] = subindex
                        
                        max = value
                    }

                } catch SpeechPipelineError.illegalState(let message) {
                    print("illegal state error \(message)")
                } catch {
                    print("Unknown Error Occurred while processing sample")
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
                    
                    match -= 1
                    if match == phrase.count {
                        break
                    }
                }
            }
            
            /// If we reached the end of a phrase, we have a match,
            /// So start the activation counter
            
            if match == phrase.count {
                
                self.activeLength = 1
                break
            }
        }
    }
}

