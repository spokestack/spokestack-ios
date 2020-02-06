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
    private var tokenizer: BertTokenizer?
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
        try self.initializeInterpreter()
        self.tokenizer = try BertTokenizer(configuration)
        self.metadata = try NLUModelMeta(configuration)
    }
    
    @objc public init(_ delegate: NLUDelegate, configuration: SpeechConfiguration) {
        self.delegate = delegate
        self.configuration = configuration
        super.init()
        do {
            self.tokenizer = try BertTokenizer(configuration)
            try self.initializeInterpreter()
            self.metadata = try NLUModelMeta(configuration)
        } catch let error {
            self.delegate?.failure(error: error)
        }
    }
    
    private func initializeInterpreter() throws {
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
        //  encode the inputs, but first concat zeros on the end of the utterance up to the expected input size (128 32-bit ints)
        let encodedInputs = inputIds + Array(repeating: 0, count: tokenizer.maxTokenLength/2 - inputIds.count)
        _ = try encodedInputs
            .withUnsafeBytes({
                try model.copy(Data($0), toInputAt: InputTensors.input.rawValue)})
        try model.invoke()
        let encodedIntentsTensor = try model.output(at: OutputTensors.intent.rawValue)
        let encodedIntents = encodedIntentsTensor.data.toArray(type: Float32.self, count: encodedIntentsTensor.data.count/4)
        let intentsArgmax = encodedIntents.argmax()
        if intentsArgmax.0 > metadata.model.intents.count {
            throw NLUError.model("NLU model returned an intent value outside the expected range.")
        }
        let intent = metadata.model.intents[intentsArgmax.0]
        let encodedTagTensor = try model.output(at: OutputTensors.tag.rawValue)
        let encodedTags = encodedTagTensor.data.toArray(type: Float32.self, count: encodedTagTensor.data.count/4)
        let encodedTagsByInputSize = encodedInputs.map({ _ in Array(encodedTags.prefix(through: inputIds.count)).argmax() }) // [(index, value)] of an encoded tag
        let tagsByInput = encodedTagsByInputSize.map(
        { metadata.model.tags[$0.0] })
        let inputTagged = zip(inputIds, tagsByInput) // input:String, tag:String tuple
        let slots = try inputTagged.reduce([:], { (dict, inputTag) in
            let name = inputTag.1
            let value = try tokenizer.decodeAndDetokenize([inputTag.0])
            guard let type = intent.slots.filter({ $0.name == name.suffix(name.range(of: "_", options: .backwards)?.lowerBound.hashValue ?? 0) }).first?.type else {
                return dict
            }
            return [name : Slot(type: type, value: value)]
        }) as [String:Slot]
        return Prediction(intent: intent.name, confidence: intentsArgmax.1, slots: slots)
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
