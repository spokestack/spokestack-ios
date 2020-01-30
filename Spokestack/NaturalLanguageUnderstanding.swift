//
//  NaturalLanguageUnderstanding.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/17/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Combine
import TensorFlowLite

@objc public class NaturalLanguageUnderstanding: NSObject {
    @objc public var configuration: SpeechConfiguration
    @objc public var delegate: NLUDelegate?
    
    private var interpreter: Interpreter?
    private var tokenizer: Tokenizer?
    private var metadata: NLUModelMeta?
    
    internal enum InputTensors: Int, CaseIterable {
        case input
    }
    
    internal enum OutputTensors: Int, CaseIterable {
        case intent
        case tag
    }
    
    @objc public init(configuration: SpeechConfiguration) throws {
        self.configuration = configuration
        super.init()
        try self.initalizeInterpreter()
        self.tokenizer = Tokenizer(configuration)
        self.metadata = try NLUModelMeta(configuration)
    }
    
    @objc public init(_ delegate: NLUDelegate, configuration: SpeechConfiguration) {
        self.delegate = delegate
        self.configuration = configuration
        self.tokenizer = Tokenizer(configuration)
        super.init()
        do {
            try self.initalizeInterpreter()
            self.metadata = try NLUModelMeta(configuration)
        } catch let error {
            self.delegate?.failure(error: error)
        }
    }
    
    private func initalizeInterpreter() throws {
        self.interpreter = try Interpreter(modelPath: self.configuration.nluModelPath)
        try self.interpreter!.allocateTensors()
        if(self.interpreter!.inputTensorCount != InputTensors.allCases.count) || (self.interpreter!.outputTensorCount != OutputTensors.allCases.count) {
            throw NLUError.model("NLU model provided is not shaped as expected. There are \(self.interpreter!.inputTensorCount)/\(InputTensors.allCases.count) inputs and \(self.interpreter!.outputTensorCount)/\(OutputTensors.allCases.count) outputs")
        }
    }

    @objc public func predict(_ input: String) -> Void {
        do {
            let prediction = try self.predict(input) as Prediction
            self.delegate?.prediction(prediction: prediction)
        } catch let error {
            self.delegate?.failure(error: error)
        }
    }
    
    @available(iOS 13.0, *)
    public func predict(inputs: [String]) ->  Publishers.Sequence<[Prediction], Never> {
        return inputs.map { try! self.predict($0) }.publisher
        //return AnyPublisher<[Prediction], Error>(try inputs.map { try self.predict($0) as Prediction })
        //return Publishers.First(upstream: Just([Prediction(intent: "", confidence: 0.0, slots: [:])]).setFailureType(to: Error.self)).eraseToAnyPublisher()
    }
    
    private func predict(_ input: String) throws -> Prediction {
        guard let model = self.interpreter else {
            throw NLUError.model("NLU model was not initialized.")
        }
        guard let tokenizer = self.tokenizer else {
            throw NLUError.tokenizer("Tokenizer was not initialized.")
        }
        guard let metadata = self.metadata else {
            throw NLUError.metadata("Metadata was not initialized.")
        }
        let inputIds = try tokenizer.tokenizeAndEncode(input)
        //  encode the inputs, but first concat zeros on the end of the utterance up to the expected input size
        let encodedInputs = inputIds + Array(repeating: 0, count: 64 - inputIds.count)
        _ = try encodedInputs
            .withUnsafeBytes({
                try model.copy(Data($0), toInputAt: InputTensors.input.rawValue)})
        try model.invoke()
        let encodedIntentsTensor = try model.output(at: OutputTensors.intent.rawValue)
        let encodedIntents = encodedIntentsTensor.data.toArray(type: Float32.self, count: encodedIntentsTensor.data.count)
        let intentsArgmax = encodedIntents.argmax()
        let intent = metadata.model.intents[(intentsArgmax.0)]
        let encodedTagTensor = try model.output(at: OutputTensors.tag.rawValue)
        let encodedTags = encodedTagTensor.data.toArray(type: Float32.self, count: encodedTagTensor.data.count)
        let tagsArgsmax = encodedTags.argmax()
        let tag = try tokenizer.decodeAndDetokenize([tagsArgsmax.0])
        return Prediction(intent: intent.name, confidence: intentsArgmax.1, slots: [:])
    }
}

@objc public protocol NLUDelegate: AnyObject {
    func prediction(prediction: Prediction) -> Void
    
    /// A trace event from the TTS system.
    /// - Parameter trace: The debugging trace message.
    func didTrace(_ trace: String) -> Void
    
    /// The TTS synthesis request has resulted in an error response.
    /// - Parameter error: The error representing the TTS response.
    func failure(error: Error) -> Void
}
