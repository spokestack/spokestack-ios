//
//  TFLiteWakewordRecognizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 8/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import Speech
import TensorFlowLite

/**
 This pipeline component streams audio samples and uses a TensorFlow Lite binary classifier to detect keyword phrases to process for wakeword recognition. Once a wakeword phrase is detected, the speech pipeline is activated.
 
 Upon activating the speech pipeline, the recognizer completes processing and awaits another coordination call. Once speech pipeline coordination via `stopStreaming` is received, the recognizer stops processing and awaits another coordination event.

 Once speech pipeline coordination via `startStreaming` is received, the recognizer begins streaming buffered frames that are first normalized and then converted to the magnitude Short-Time Fourier Transform (STFT) representation over a hopped sliding window. This linear spectrogram is then converted to a mel spectrogram via a "filter" TensorFlow model. These mel frames are batched together into a sliding window.

 The mel spectrogram represents the features to be passed to the autoregressive encoder (usually an rnn or crnn), which is implemented in an "encode" TensorFlow model. This encoder outputs an encoded vector and a state vector. The encoded vectors are batched together into a sliding window for classification, and the state vector is used to perform the autoregressive transduction over the mel frames.
 
 The "detect" TensorFlow model takes the encoded sliding window and outputs a single posterior value in the range [0, 1]. The higher the value, the more likely a keyword phrase is detected. This classifier is commonly implemented as an attention mechanism over the encoder window.
 
 The detector's outputs are then compared against a configured threshold in order to determine whether to activate the pipeline. If the posterior is greater than the threshold, the pipeline is activated.
*/
public class TFLiteWakewordRecognizer: NSObject {
    
    // MARK: Public (properties)
    
    /// Singleton instance.
    @objc public static let sharedInstance: TFLiteWakewordRecognizer = TFLiteWakewordRecognizer()
    
    /// Delegate which receives speech pipeline control events.
    public weak var delegate: SpeechEventListener?
    
    /// Configuration for the recognizer.
    public var configuration: SpeechConfiguration? = SpeechConfiguration() {
        didSet {
            if configuration != nil {
                self.validateConfiguration()
                self.configureAttentionModels()
                self.setConfiguration()
            }
        }
    }

    /// Global state for the speech pipeline.
    public var context: SpeechContext = SpeechContext()
    
    // MARK: Private (properties)
    
    internal enum Tensors: Int, CaseIterable {
        case encode
        case state
    }
    
    private var vad: WebRTCVAD = WebRTCVAD()
    
    /// Wakeword Activation Management
    private var activeLength: Int = 0
    private var minActive: Int = 0
    private var maxActive: Int = 0
    private var isSpeech: Bool = false
    
    /// TensorFlowLite models
    private var filterModel: Interpreter?
    private var encodeModel: Interpreter?
    private var detectModel: Interpreter?
    
    /// filtering for STFL/MEL
    private var fftFrame: Array<Float> = []
    private var frameWindow: RingBuffer<Float>!
    private var hopLength: Int = 0
    private var melWidth: Int = 0
    private var sampleWindow: RingBuffer<Float>!
    private var fftWindow: Array<Float> = []
    private var fft: FFT!
    
    /// Audio Signal Normalization
    private var rmsAlpha: Float = 0.0
    private var rmsTarget: Float = 0.0
    private var rmsValue: Float = 0.0
    private var preEmphasis: Float = 0.0
    private var prevSample: Float = 0.0
    
    /// attention model buffers
    private var encodeWidth: Int = 0
    private var encodeLength: Int = 0
    private var stateWidth: Int = 0
    private var encodeWindow: RingBuffer<Float>!
    private var encodeState: RingBuffer<Float>!
    private var detectWindow: RingBuffer<Float>!
    
    /// attention model posteriors
    private var posteriorThreshold: Float = 0

    /// Tracing
    private var traceLevel: Trace.Level = Trace.Level.NONE
    private var sampleCollector: Array<Float>?
    private var fftFrameCollector: String?
    private var filterCollector: Array<Float>?
    private var encodeCollector: Array<Float>?
    private var stateCollector: Array<Float>?
    private var detectCollector: Array<Float>?
    private var posteriorMax: Float?

    // MARK: NSObject methods
    
    deinit {
    }
    
    public override init() {
        super.init()
    }
    
    // MARK: Private functions
    
    // MARK: Configuration processing
    
    private func validateConfiguration() -> Void {
        if let c = self.configuration {
            /// Validate stft/mel spectrogram configuration
            let windowSize: Int = c.fftWindowSize
            if windowSize % 2 != 0 {
                assertionFailure("TFLiteWakewordRecognizer validateConfiguration invalid fft-window-size")
                return
            }
        }
    }
    
    private func configureAttentionModels() -> Void {
        /// tensorflow model initialization
        if let c = self.configuration {
            do {
                self.filterModel = try Interpreter(modelPath: c.filterModelPath)
                if let model = self.filterModel {
                    try model.allocateTensors()
                } else {
                    throw WakewordModelError.filter("\(c.filterModelPath) could not be initialized")
                }
                
                self.encodeModel = try Interpreter(modelPath: c.encodeModelPath)
                if let model = self.encodeModel {
                    try model.allocateTensors()
                    assert(model.inputTensorCount == Tensors.allCases.count)
                } else {
                    throw WakewordModelError.encode("\(c.encodeModelPath) could not be initialized")
                }
                
                self.detectModel = try Interpreter(modelPath: c.detectModelPath)
                if let model = self.detectModel {
                    try model.allocateTensors()
                } else {
                    throw WakewordModelError.detect("\(c.detectModelPath) could not be initialized")
                }
            } catch let message {
                self.delegate!.didError(WakewordModelError.model("TFLiteWakewordRecognizer configureAttentionModels \(message)"))
            }
        }
    }
    
    private func setConfiguration() -> Void {
        if let c = self.configuration {
            
            /// Tracing
            self.traceLevel = c.tracing
            if self.traceLevel.rawValue <= Trace.Level.DEBUG.rawValue {
                self.posteriorMax = 0
                self.sampleCollector = []
                self.fftFrameCollector = ""
                self.filterCollector = []
                self.encodeCollector = []
                self.stateCollector = []
                self.detectCollector = []
            }

            /// VAD
            do {
                try self.vad.create(mode: c.vadMode, delegate: self, frameWidth: c.frameWidth, sampleRate: c.sampleRate)
            } catch {
                assertionFailure("TFLiteWakewordRecognizer failed to create a valid VAD")
            }
            
            /// Signal normalization
            self.rmsAlpha = c.rmsAlpha
            self.rmsTarget = c.rmsTarget
            self.rmsValue = self.rmsTarget
            self.preEmphasis = c.preEmphasis

            /// Sliding window buffers
            self.fftFrame = Array(repeating: 0.0, count: c.fftWindowSize)
            self.melWidth = c.melFrameWidth
            self.hopLength = c.fftHopLength * c.sampleRate / 1000
            let melLength: Int = c.melFrameLength * c.sampleRate / 1000 / self.hopLength
            self.frameWindow = RingBuffer(melLength * self.melWidth, repeating: 0.0)
            self.sampleWindow = RingBuffer(c.fftWindowSize, repeating: 0.0)
            self.fftWindow = SignalProcessing.fftWindowDispatch(windowType: c.fftWindowType, windowLength: c.fftWindowSize)
            self.fft = FFT(c.fftWindowSize)
            
            /// Attention model buffers
            self.encodeWidth = c.encodeWidth
            self.encodeLength = c.encodeLength * c.sampleRate / 1000 / self.hopLength
            self.stateWidth = c.stateWidth
            self.encodeWindow = RingBuffer(self.encodeLength * c.encodeWidth, repeating: 0.0)
            self.encodeState = RingBuffer(c.stateWidth, repeating: 0.0)
            self.encodeState.fill(0.0)
            self.detectWindow = RingBuffer(self.encodeLength * c.encodeWidth, repeating: 0.0)
            
            /// attention model posteriors
            self.posteriorThreshold = c.wakeThreshold
            self.posteriorMax = 0
            
            /// Wakeword activation lengths
            let frameWidth: Int = c.frameWidth
            self.minActive = c.wakeActiveMin / frameWidth
            self.maxActive = c.wakeActiveMax / frameWidth
        }
    }
    
    /// MARK: Audio processing
    
    private func sample(_ data: Data) throws -> Void {
        
        /// Preallocate an array of data elements in the frame for use in RMS and sampling
        let dataElements: Array<Int16> = data.elements()
        
        /// Update the rms normalization factors
        /// Maintain an ewma of the rms signal energy for speech samples
        if self.rmsAlpha > 0 {
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
            try self.sampleWindow.write(sample)
            if self.sampleWindow.isFull {
                try self.analyze()
            }
        }
    }
    
    private func analyze() throws -> Void {
        /// The current sample window contains speech, so
        /// apply the fft windowing function to it
        for (index, _) in self.fftFrame.enumerated() {
            let sample: Float = try self.sampleWindow.read()
            self.fftFrame[index] = sample * self.fftWindow[index]
        }
        
        /// Compute the stft spectrogram
        self.fft.forward(&self.fftFrame)
        
        /// rewind the sample window for another run
        self.sampleWindow.rewind().seek(self.hopLength)
        
        if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
            self.fftFrameCollector? += "\(self.fftFrame)\n"
        }
        
        /// send sampleWindow to filter model
        try self.filter()
    }
    
    /// Attention model processing
    
    private func filter() throws -> Void {
        do {
            if let model = self.filterModel {
                /// inputs
                /// compute the manitude of the spectrogram
                let magnitude = (self.fftFrame.count / 2) + 1
                /// copy the spectrogram into the filter model's input
                _ = try self
                    .fftFrame
                    .prefix(magnitude)
                    .withUnsafeBytes(
                        {try model.copy(Data($0), toInputAt: 0)})
                
                /// calculate
                try model.invoke()
                
                /// outputs
                let output = try model.output(at: 0)
                let results = output.data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float32] in
                    Array<Float32>(UnsafeBufferPointer(start: pointer.bindMemory(to: Float32.self).baseAddress, count: output.data.count / 4))
                }
                self.frameWindow.rewind().seek(self.melWidth)
                for r in results {
                    try self.frameWindow.write(r)
                    if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
                        self.filterCollector?.append(r)
                    }
                }
                
                /// send frameWinodw to encoding model
                try self.encode()
            } else {
                throw WakewordModelError.filter("model was not initialized")
            }
        } catch let message {
            throw WakewordModelError.filter("TFLiteWakewordRecognizer filter \(message)")
        }
    }
    
    private func encode() throws -> Void {
        do {
            if let model = self.encodeModel {
                /// inputs
                self.frameWindow.rewind()
                // TODO: model.copy requires that the data be sized to exactly the same as the tensor, so we can't just do read()s off the ringbuffer and copy over piecewise. This introduces an aggrevating overhead of having to copy the ringbuffer into an array before copying over to the tensor. Maybe use a fixed-sized array that is advanced based off the fft frame size?
                var frameWindowArray: Array<Float32> = []
                while !self.frameWindow.isEmpty {
                    let f = try self.frameWindow.read()
                    frameWindowArray.append(f)
                }
                var stateArray: Array<Float32> = []
                for _ in 0..<self.stateWidth {
                    let f = try self.encodeState.read()
                    stateArray.append(f)
                }
                _ = try frameWindowArray
                    .withUnsafeBytes(
                        {try model.copy(Data($0), toInputAt: Tensors.encode.rawValue)})
                _ = try stateArray
                    .withUnsafeBytes(
                        {try model.copy(Data($0), toInputAt: Tensors.state.rawValue)})
                
                /// calculate
                try model.invoke()
                
                /// outputs
                let encodeOutput = try model.output(at: Tensors.encode.rawValue)
                let encodeResults = encodeOutput.data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float32] in
                    Array<Float32>(UnsafeBufferPointer(start: pointer.bindMemory(to: Float32.self).baseAddress, count: encodeOutput.data.count / 4))}
                self.encodeWindow.rewind().seek(self.encodeWidth)
                for r in encodeResults {
                    try self.encodeWindow.write(r)
                    if self.traceLevel.rawValue < Trace.Level.PERF.rawValue {
                        self.encodeCollector?.append(r)
                    }
                }
                let stateOutput = try model.output(at: Tensors.state.rawValue)
                let stateResults = stateOutput.data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float32] in
                    Array<Float32>(UnsafeBufferPointer(start: pointer.bindMemory(to: Float32.self).baseAddress, count: stateOutput.data.count / 4))}
                for r in stateResults {
                    try self.encodeState.write(r)
                }
            } else {
                throw WakewordModelError.encode("model was not initialized")
            }
        }
    }
    
    private func detect() throws -> Bool {
        if self.encodeWindow.isFull {
            do {
                if let model = self.detectModel {
                    /// inputs
                    var encodeWindowArray: Array<Float32> = []
                    self.encodeWindow.rewind()
                    while !self.encodeWindow.isEmpty {
                        let f = try self.encodeWindow.read()
                        encodeWindowArray.append(f)
                    }
                    _ = try encodeWindowArray
                        .withUnsafeBytes(
                            {try model.copy(Data($0), toInputAt: 0)})
                    
                    /// calculate
                    try model.invoke()
                    
                    /// outputs
                    let detectOutput = try model.output(at: 0)
                    let detectResults = detectOutput.data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) -> [Float32] in
                        Array<Float32>(UnsafeBufferPointer(start: pointer.bindMemory(to: Float32.self).baseAddress, count: detectOutput.data.count / 4))}
                    let posterior = detectResults[0]
                    
                    if let pmax = self.posteriorMax {
                        if self.traceLevel.rawValue < Trace.Level.INFO.rawValue {
                            if posterior > pmax {
                                self.posteriorMax = posterior
                            }
                        }
                    }
                    
                    if posterior > self.posteriorThreshold {
                        return true
                    }
                 }
            }
        }
        return false
    }
    
    private func reset() -> Void {
        self.debug()
        
        /// Empty the sample buffer, so that only contiguous
        /// speech samples are written to it
        self.sampleWindow.reset()
        
        /// Reset and fill the other buffers,
        /// which prevents them from lagging the detection
        self.frameWindow.reset().fill(0)
        self.encodeWindow.reset().fill(0)
        self.encodeState.reset().fill(0)
        self.detectWindow.reset().fill(0)
        
        /// reset the maximum posterior
        self.posteriorMax = 0
        
        /// control flow deactivation
        self.activeLength = 0
}
    
    private func debug() -> Void {
        Trace.trace(Trace.Level.PERF, configLevel: self.traceLevel, message: "wake: \(self.posteriorMax!)", delegate: self.delegate, caller: self)
        
        if self.traceLevel.rawValue <= Trace.Level.DEBUG.rawValue {
            Trace.spit(data: "[\((self.sampleCollector! as NSArray).componentsJoined(by: ", "))]".data(using: .utf8)!, fileName: "samples.txt", delegate: self.delegate!)
            Trace.spit(data: self.fftFrameCollector!.data(using: .utf8)!, fileName: "fftFrame.txt", delegate: self.delegate!)
            Trace.spit(data: "[\((self.filterCollector! as NSArray).componentsJoined(by: ", "))]".data(using: .utf8)!, fileName: "filterOutput.txt", delegate: self.delegate!)
            Trace.spit(data: "[\((self.encodeCollector! as NSArray).componentsJoined(by: ", "))]".data(using: .utf8)!, fileName: "encodeOutput.txt", delegate: self.delegate!)
            Trace.spit(data: "[\((self.stateCollector! as NSArray).componentsJoined(by: ", "))]".data(using: .utf8)!, fileName: "stateOutput.txt", delegate: self.delegate!)
        }
    }
}

// MARK: SpeechProcessor implementation

extension TFLiteWakewordRecognizer : SpeechProcessor {

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

extension TFLiteWakewordRecognizer: AudioControllerDelegate {
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    ///
    /// Processes audio in an async thread.
    /// - Parameter frame: Frame of audio samples.
    func process(_ frame: Data) -> Void {
        /// multiplex the audio frame data to both the vad and, if activated, the model pipelines
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
        
            /// always run the frame through the vad, since that will determine speech activation/deactivation edges
            do { try strongSelf.vad.process(frame: frame, isSpeech:
                strongSelf.context.isSpeech) }
            catch let error {
                strongSelf.delegate?.didError(error)
            }
            
            /// if the vad is detecting speech, check for wakeword activation
            if strongSelf.context.isSpeech {
                if !strongSelf.context.isActive {
                    /// Run the current frame through the detector pipeline.
                    /// Activate the pipeline if a keyword phrase was detected.
                    do {
                        strongSelf.activeLength = 0
                        /// Decode the FFT outputs into the filter model's input
                        try strongSelf.sample(frame)
                        let activate = try strongSelf.detect()
                        if activate {
                            strongSelf.context.isActive = true
                            strongSelf.reset()
                            strongSelf.stopStreaming(context: strongSelf.context)
                            strongSelf.delegate?.activate()
                        }
                    } catch let error {
                        strongSelf.delegate?.didError(error)
                    }
                } else {
                    strongSelf.activeLength += 1
                    /// Continue this wakeword (or external) activation
                    /// for at least the activation minimum,
                    /// until a vad deactivation or timeout
                    if (strongSelf.activeLength > strongSelf.minActive) && (strongSelf.activeLength >= strongSelf.maxActive) {
                        strongSelf.context.isActive = false
                        strongSelf.delegate?.deactivate()
                    }
                }
            /// detect speech deactivation edge
            } else if strongSelf.isSpeech {
                if !strongSelf.context.isActive {
                    strongSelf.debug()
                }
            }
            strongSelf.isSpeech = strongSelf.context.isSpeech
        }
    }
}

// MARK: VADDelegate implementation

extension TFLiteWakewordRecognizer: VADDelegate {
    
    /// Called when the VAD has detected speech.
    /// - Parameter frame: The first frame of audio samples with speech detected in it.
    public func activate(frame: Data) {
        /// activate the speech context
        self.context.isSpeech = true
        /// process the first frames of speech data from the vad
        self.process(frame)
    }
    
    /// Called when the VAD as stopped detecting speech.
    public func deactivate() {
        if !self.context.isActive ||
            (self.context.isActive && self.activeLength >= self.maxActive) {
            self.context.isSpeech = false
        }
    }
}
