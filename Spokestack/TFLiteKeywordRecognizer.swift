//
//  TFLiteKeywordRecognizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 12/7/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import TensorFlowLite

@objc public class TFLiteKeywordRecognizer: NSObject {

    /// Configuration for the recognizer.
    @objc public var configuration: SpeechConfiguration

    /// Global state for the speech pipeline.
    @objc public var context: SpeechContext

    private var isActive: Bool = false
    private var activation = 0

    private var prevSample: Float = 0.0
    private var sampleWindow: RingBuffer<Float>!
    private var fftFrame: Array<Float> = []
    private var fftWindow: Array<Float> = []
    private var fft: FFT!
    private var hopLength: Int = 0
    private var frameWindow: RingBuffer<Float>!
    private var encodeState: RingBuffer<Float>!
    private var encodeWindow: RingBuffer<Float>!
    private var classes: [String] = []

    // TensorFlowLite models
    private var filterModel: Interpreter?
    private var encodeModel: Interpreter?
    private var detectModel: Interpreter?
    internal enum Tensors: Int, CaseIterable {
        case encode
        case state
    }

    private var sampleCollector: Array<Float>?
    private var fftFrameCollector: String?
    private var filterCollector: Array<Float>?
    private var encodeCollector: Array<Float>?

    /// Initializes a TFLiteKeywordRecognizer instance.
    ///
    /// A recognizer is initialized by, and receives `startStreaming` and `stopStreaming` events from, an instance of `SpeechPipeline`.
    ///
    /// The TFLiteKeywordRecognizer receives audio data frames to `process` from `AudioController`.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
        self.initialize(configuration)
    }
    
    private func initialize(_ c: SpeechConfiguration) {
        self.sampleWindow = RingBuffer(c.keywordFFTWindowSize, repeating: 0.0)
        self.fftFrame = Array(repeating: 0.0, count: c.keywordFFTWindowSize)
        self.fftWindow = SignalProcessing.fftWindowDispatch(windowType: c.keywordFFTWindowType, windowLength: c.keywordFFTWindowSize)
        self.fft = FFT(c.keywordFFTWindowSize)
        self.hopLength = c.keywordFFTHopLength * c.sampleRate / 1000
        let melLength: Int = c.keywordMelFrameLength * c.sampleRate / 1000 / self.hopLength
        self.frameWindow = RingBuffer(melLength * c.keywordMelFrameWidth, repeating: 0.0)
        self.encodeState = RingBuffer(c.keywordEncodeWidth, repeating: 0.0)
        self.encodeState.fill(0.0) // fill now because the encoded state is used to feed-forward
        let encodeLength = c.keywordEncodeLength * c.sampleRate / 1000 / self.hopLength
        self.encodeWindow = RingBuffer(encodeLength * c.keywordEncodeWidth, repeating: -1.0)
        do {
            let keywords = try CommandModelMeta(configuration)
            self.classes = keywords.model.classes.flatMap({ c in
                return c.utterances.map({ u in
                    return u.text
                })
            })
        } catch {
            self.classes = self.configuration.keywords.components(separatedBy: ",")
        }
        
        // Tracing
        if c.tracing.rawValue <= Trace.Level.DEBUG.rawValue {
            self.sampleCollector = []
            self.fftFrameCollector = ""
            self.filterCollector = []
            self.encodeCollector = []
        }
        
        // tensorflow model initialization
        do {
            self.filterModel = try Interpreter(modelPath: c.keywordFilterModelPath)
            if let model = self.filterModel {
                try model.allocateTensors()
            } else {
                throw CommandModelError.filter("\(c.keywordFilterModelPath) could not be initialized")
            }
            
            self.encodeModel = try Interpreter(modelPath: c.keywordEncodeModelPath)
            if let model = self.encodeModel {
                try model.allocateTensors()
                if model.inputTensorCount != Tensors.allCases.count {
                    throw CommandModelError.encode("Keyword encode model input dimension is \(model.inputTensorCount) which does not matched expected dimension \(Tensors.allCases.count)")
                }
            } else {
                throw CommandModelError.encode("\(c.keywordEncodeModelPath) could not be initialized")
            }
            
            self.detectModel = try Interpreter(modelPath: c.keywordDetectModelPath)
            if let model = self.detectModel {
                try model.allocateTensors()
                let rank: Int = try model.output(at: 0).shape.dimensions[1]
                if rank != self.classes.count {
                    throw CommandModelError.detect("The \(self.classes.count) keywords defined by SpeechConfiguration.keywords does not match the \(rank) expected by the model at SpeechConfiguration.keywordDetectModelPath.")
                }
            } else {
                throw CommandModelError.detect("\(c.keywordDetectModelPath) could not be initialized")
            }
        } catch let message {
            self.context.dispatch { $0.failure(error: CommandModelError.model("TFLiteKeywordRecognizer configureAttentionModels \(message)")) }
        }
    }
    
    private func sample(_ frame: Data) throws {
        // Preallocate an array of data elements in the frame for use in sampling
        let elements: Array<Int16> = frame.elements()
        
        // Process all samples in the frame
        for e in elements {
            // Normalize and clip the 16-bit sample
            var sample: Float = Float(e) / Float(Int16.max)
            sample = max(-1.0, min(sample, 1.0))
            
            // Run a pre-emphasis filter to balance high frequencies and eliminate any dc energy
            let currentSample: Float = sample
            sample -= self.configuration.preEmphasis * self.prevSample
            self.prevSample = currentSample
            
            if self.configuration.tracing.rawValue <= Trace.Level.DEBUG.rawValue {
                self.sampleCollector?.append(sample)
            }
            
            // Process the sample
            // - write it to the sample sliding window
            // - run the remainder of the detection pipleline if speech
            // - advance the sample sliding window
            try self.sampleWindow.write(sample)
            if self.sampleWindow.isFull {
                if self.isActive {
                    try self.analyze()
                }
                // rewind the sample window for another run
                self.sampleWindow.rewind().seek(self.hopLength)
            }
        }
    }
    
    private func analyze() throws {
        // The current sample window contains speech, so apply the fft windowing function to it
        for (index, _) in self.fftFrame.enumerated() {
            let sample: Float = try self.sampleWindow.read()
            self.fftFrame[index] = sample * self.fftWindow[index]
        }
        
        // Compute the stft spectrogram
        self.fft.forward(&self.fftFrame)
        
        if self.configuration.tracing.rawValue <= Trace.Level.DEBUG.rawValue {
            self.fftFrameCollector? += "\(self.fftFrame)\n"
        }
        
        try self.filter()
    }
    
    private func filter() throws -> Void {
        // utilize the stft spectrogram as input for the filter model
        do {
            guard let model = self.filterModel else {
                throw CommandModelError.filter("model was not initialized")
            }
            // inputs
            // compute the magnitude of the spectrogram
            let magnitude = (self.fftFrame.count / 2) + 1
            // copy the spectrogram into the filter model's input
            _ = try self
                .fftFrame
                .prefix(magnitude)
                .withUnsafeBytes(
                    {try model.copy(Data($0), toInputAt: 0)})
            
            // calculate
            try model.invoke()
            
            // outputs
            let output = try model.output(at: 0)
            let results = output.data.toArray(type: Float32.self, count: output.data.count / 4)
            self.frameWindow.rewind().seek(self.configuration.keywordMelFrameWidth)
            for r in results {
                try self.frameWindow.write(r)
                if self.configuration.tracing.rawValue <= Trace.Level.DEBUG.rawValue {
                    self.filterCollector?.append(r)
                }
            }
        } catch let message {
            throw CommandModelError.filter("TFLiteKeywordRecognizer filter \(message)")
        }
        
        // send frameWindow to encoding model
        try self.encode()
    }
    
    private func encode() throws -> Void {
        do {
            guard let model = self.encodeModel else {
                throw CommandModelError.encode("model was not initialized")
            }
            // inputs: frameWindow and encodeState
            self.frameWindow.rewind()
            // TODO: model.copy requires that the data be sized to exactly the same as the tensor, so we can't just do read()s off the ringbuffer and copy over piecewise. This introduces an aggrevating overhead of having to copy the ringbuffer into an array before copying over to the tensor. Maybe use a fixed-sized array that is advanced based off the fft frame size?
            var frameWindowArray: Array<Float32> = []
            while !self.frameWindow.isEmpty {
                let f = try self.frameWindow.read()
                frameWindowArray.append(f)
            }
            var stateArray: Array<Float32> = []
            for _ in 0..<self.configuration.keywordEncodeWidth {
                let f = try self.encodeState.read()
                stateArray.append(f)
            }
            _ = try frameWindowArray
                .withUnsafeBytes(
                    {try model.copy(Data($0), toInputAt: Tensors.encode.rawValue)})
            _ = try stateArray
                .withUnsafeBytes(
                    {try model.copy(Data($0), toInputAt: Tensors.state.rawValue)})
            
            // calculate
            try model.invoke()
            
            // outputs
            let encodeOutput = try model.output(at: Tensors.encode.rawValue)
            let encodeResults = encodeOutput.data.toArray(type: Float32.self, count: encodeOutput.data.count / 4)
            self.encodeWindow.rewind().seek(self.configuration.keywordEncodeWidth)
            for r in encodeResults {
                try self.encodeWindow.write(r)
                if self.configuration.tracing.rawValue <= Trace.Level.DEBUG.rawValue {
                    self.encodeCollector?.append(r)
                }
            }
            let stateOutput = try model.output(at: Tensors.state.rawValue)
            let stateResults = stateOutput.data.toArray(type: Float32.self, count: stateOutput.data.count / 4)
            for r in stateResults {
                try self.encodeState.write(r)
            }
        } catch let message {
            throw CommandModelError.encode("TFLiteKeywordRecognizer encode \(message)")
        }
    }
    
    private func detect() throws {
        if self.encodeWindow.isFull {
            do {
                guard let model = self.detectModel else {
                    throw CommandModelError.encode("model was not initialized")
                }
                // inputs: encodeWindow
                var encodeWindowArray: Array<Float32> = []
                self.encodeWindow.rewind()
                while !self.encodeWindow.isEmpty {
                    let f = try self.encodeWindow.read()
                    encodeWindowArray.append(f)
                }
                _ = try encodeWindowArray
                    .withUnsafeBytes(
                        {try model.copy(Data($0), toInputAt: 0)})
                
                // calculate
                try model.invoke()
                
                // outputs
                let detectOutput = try model.output(at: 0)
                let detectResults = detectOutput.data.toArray(type: Float32.self, count: detectOutput.data.count / 4)
                
                // if the argmax of the distribution of class posteriors exceeeds the threshold, emit a recognition of that class, otherwise timeout.
                let classArgmax = detectResults.argmax()
                
                Trace.trace(.INFO, message: "detected \(self.classes[classArgmax.0]) \(classArgmax)", config: self.configuration, context: self.context, caller: self)
                
                if classArgmax.1 > self.configuration.keywordThreshold {
                    self.context.confidence = classArgmax.1
                    self.context.transcript = self.classes[classArgmax.0]
                    self.context.dispatch { $0.didRecognize?(self.context) }
                } else {
                    self.context.dispatch { $0.didTimeout?() }
                }
                self.reset()
            } catch let message {
                throw CommandModelError.detect("TFLiteKeywordRecognizer detect \(message)")
            }
        }
    }
    
    private func reset() -> Void {
        // Empty the sample buffer, so that only contiguous speech samples are written to it
        self.sampleWindow.reset()
        
        // Reset and fill the other buffers, which prevents them from lagging the detection
        self.frameWindow.reset().fill(0)
        self.encodeWindow.reset().fill(-1.0)
        self.encodeState.reset().fill(0)
    }
}

extension TFLiteKeywordRecognizer : SpeechProcessor {
    
    public func startStreaming() {}
    
    public func stopStreaming() {
        self.isActive = false
    }
    
    public func process(_ frame: Data) {
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            do {
                if strongSelf.context.isActive {
                    // sample every frame while active
                    try strongSelf.sample(frame)
                    if !strongSelf.isActive {
                        strongSelf.isActive = true
                    } else if
                        (strongSelf.isActive
                            && strongSelf.activation <= strongSelf.configuration.wakeActiveMax)
                            ||
                            strongSelf.activation <= strongSelf.configuration.wakeActiveMin {
                        // already sampled, but in the midst of activation, so don't deactiavte yet
                        strongSelf.activation += strongSelf.configuration.frameWidth
                    } else {
                        strongSelf.run()
                        strongSelf.deactivate()
                    }
                } else if strongSelf.isActive {
                    try strongSelf.sample(frame)
                    strongSelf.run()
                    strongSelf.deactivate()
                }
            } catch let error {
                strongSelf.context.dispatch { $0.failure(error: error) }
            }
        }
    }
    
    private func deactivate() {
        self.context.isActive = false
        self.isActive = false
        self.activation = 0
        self.context.dispatch { $0.didDeactivate?() }
    }
    
    private func run() {
        do {
            try self.detect()
        } catch let error {
            self.context.dispatch { $0.failure(error: error) }
        }
    }
}
