//
//  WakeWordController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

class WakeWordController {
    
    // MARK: Internal (properties)
    
    enum FFTWindowType: String {
        case hann
    }
    
    // MARK: Private (properties)
    
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
    
    private var wakeWordConfiguration: WakeRecognizerConfiguration
    
    private let audioController: AudioController = AudioController()
    
    private let audioEngineController: AudioEngineController
    
    // MARK: Initializers
    
    init(_ configuration: WakeRecognizerConfiguration) {
        
        self.wakeWordConfiguration = configuration
        
        let buffer: Int = configuration.sampleRate / 1000 * configuration.frameWidth
        self.audioEngineController = AudioEngineController(buffer)
        
        self.setup()
    }
    
    // MARK: Internal (methods)
    
    func activate() -> Void {
        self.audioEngineController.startRecording()
    }
    
    func deactivate() -> Void {
        
    }
    
    // MARK: Private (methods)
    
    private func setup() -> Void {

        /// Parse the configured list of keywords
        /// Allocate an additional slot for the non-keyword class at 0
        
        let wakeWords: Array<String> = self.wakeWordConfiguration.wakeWords.components(separatedBy: ",")
        print("wakeWords \(wakeWords)")
        self.words = wakeWords
        
        /// Parse the keyword phrase configuration
        
        var wakePhrases: Array<String> = self.wakeWordConfiguration.wakePhrases.components(separatedBy: ",")
        print("local wakePhrases \(wakePhrases)")

        self.phrases = TwoDimensionArray<Int>.init(repeating: [0], count: wakePhrases.count)
        print("self.phrases \(self.phrases)")
        
        for (index, _) in wakePhrases.enumerated() {
            
            let wakePhrase: String = wakePhrases[index]
            let wakePhraseArray: Array<String> = wakePhrase.components(separatedBy: " ")
            print("wakePhraseArray \(wakePhraseArray)")
            
            /// Allocate an additional (null) slot at the end of each phrase,
            /// which forces the phraser to continue detection until the end
            /// of the final keyword in each phrase
            
            self.phrases[index] = Array<Int>.init(repeating: 0, count: wakePhrases.count + 1)
            
            print("self.phrases after setting \(self.phrases)")
            
            for (j, v) in wakePhraseArray.enumerated() {
                print("what is the [v] \(v) for [j] \(j) wakePhraseArray")
                
                guard let k: Int = wakeWords.index(of: wakePhraseArray[j]) else {
                    
                    assertionFailure("wake-phrases")
                    return
                }
                
                self.phrases[index][j] = k + 1
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
    
    private func sample(_ data: Data) -> Void {
        
        /// Update the rms normalization factors
        /// Maintain an ewma of the rms signal energy for speech samples
        
        self.rmsValue = self.rmsAlpha * self.rms(data) + (1 - self.rmsAlpha) * self.rmsValue
        
        /// Process all samples in the frame
        var newData = data
        let range = data.startIndex..<data.endIndex
        newData.resetBytes(in: range)

        while !newData.isEmpty {
            
            /// Normalize and clip the 16-bit sample to the target rms energy
            
            var sample: Float = Float(newData[newData.index(newData.startIndex, offsetBy: 2)]) / .greatestFiniteMagnitude
            
            sample = sample * (self.rmsTarget / self.rmsValue)
            sample = max(-1.0, min(sample, 1.0))
            
            /// Process the sample
            /// Write it to the sample sliding window
            /// run the remainder of the detection pipleline if speech
            /// advance the sample sliding window
            
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

    private func rms(_ data: Data) -> Float {
    
        var sum: Float = 0
        var count: Int = 0
        var newData = data

//        let range = newData.startIndex..<newData.index(newData.startIndex, offsetBy: 1)
        let range = newData.startIndex..<newData.endIndex
        newData.resetBytes(in: range)

        while !data.isEmpty {

            let sample: Float = Float(newData[newData.index(newData.startIndex, offsetBy: 2)]) / .greatestFiniteMagnitude

            sum += sample * sample
            count += 1
        }
        
        return Float(sqrt(sum / Float(count)))
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
        
        /// Decode the FFT outputs into the filter model's input
        /// Compute the nagitude (abs) of each complex stft component
        /// The first and last stft components contain only real parts
        /// and are stored in the first of the first two positions of the stft
        /// output. The remaining components contact real / imaginary parts
        
        /// Execute the mel filterbank tensorflow model
        
        /// Copy the current mel frame into the mel window
        
        /// Detect
        
        self.detect()
        
//        // decode the FFT outputs into the filter model's inputs
//        // . compute the magnitude (abs) of each complex stft component
//        // . the first and last stft components contain only real parts
//        //   and are stored in the first two positions of the stft output
//        // . the remaining components contain real/imaginary parts
//        this.filterModel.inputs().rewind();
//        this.filterModel.inputs().putFloat(this.fftFrame[0]);
//        for (int i = 1; i < this.fftFrame.length / 2; i++) {
//            float re = this.fftFrame[i * 2 + 0];
//            float im = this.fftFrame[i * 2 + 1];
//            float ab = (float) Math.sqrt(re * re + im * im);
//            this.filterModel.inputs().putFloat(ab);
//        }
//        this.filterModel.inputs().putFloat(this.fftFrame[1]);
//
//        // execute the mel filterbank tensorflow model
//        this.filterModel.run();
//
//        // copy the current mel frame into the mel window
//        this.frameWindow.rewind().seek(this.melWidth);
//        while (this.filterModel.outputs().hasRemaining())
//        this.frameWindow.write(this.filterModel.outputs().getFloat());
//
//        detect();
    }
    
    private func detect() -> Void {

        /// Transfer the mel filterbank window to the detector model's inputs
        
        self.frameWindow.rewind()
        
        /// Setup CoreML
        
        /// Run against CoreML
        
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
            
            index += 1
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
