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
    private var terminatorToken: Int
    private var paddingToken: Int
    private var maxTokenLength: Int?
    
    internal enum InputTensors: Int, CaseIterable {
        case input
    }
    
    internal enum OutputTensors: Int, CaseIterable {
        case intent
        case tag
    }
    
    @objc public init(configuration: SpeechConfiguration) throws {
        self.configuration = configuration
        self.terminatorToken = configuration.nluTerminatorTokenIndex
        self.paddingToken = configuration.nluPaddingTokenIndex
        super.init()
        try self.initializeInterpreter()
        guard let model = self.interpreter else {
            throw NLUError.model("NLU model was not initialized.")
        }
        let inputTensor = try model.input(at: InputTensors.input.rawValue)
        let inputMaxTokenLength =         inputTensor.shape.dimensions[InputTensors.input.rawValue]
        self.maxTokenLength = inputMaxTokenLength
        self.tokenizer = try BertTokenizer(configuration)
        self.tokenizer?.maxTokenLength = inputMaxTokenLength
        self.metadata = try NLUModelMeta(configuration)
    }
    
    @objc public init(_ delegate: NLUDelegate, configuration: SpeechConfiguration) throws {
        self.delegate = delegate
        self.configuration = configuration
        self.terminatorToken = configuration.nluTerminatorTokenIndex
        self.paddingToken = configuration.nluPaddingTokenIndex
        do {
            super.init()
            try self.initializeInterpreter()
            guard let model = self.interpreter else {
                throw NLUError.model("NLU model was not initialized.")
            }
            let inputTensor = try model.input(at: InputTensors.input.rawValue)
            let inputMaxTokenLength = inputTensor.shape.dimensions[1]
            self.maxTokenLength = inputMaxTokenLength
            self.tokenizer = try BertTokenizer(configuration)
            self.tokenizer?.maxTokenLength = inputMaxTokenLength
            self.metadata = try NLUModelMeta(configuration)
        } catch let error {
            delegate.failure(error: error)
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
        guard let maxInputTokenLength = self.maxTokenLength else {
            throw NLUError.invalidConfiguration("NLU model maximum input tokens length was not set.")
        }
        //  encode the input, terminate the utterance with the terminator token, and  pad from the end of the utterance up to the expected input size (128 32-bit ints)
        var encodedInput = try tokenizer.tokenizeAndEncode(input)
        encodedInput.append(self.terminatorToken)
        encodedInput += Array(repeating: self.paddingToken, count: maxInputTokenLength - encodedInput.count)
        let downcastEncodedInput = encodedInput.map({ Int32(truncatingIfNeeded: $0) })
        _ = try downcastEncodedInput
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
        let encodedTagsArgmax = stride(from: 0,
                                       to: encodedTags.count,
                                       by: metadata.model.tags.count)
            .map({
                Array(encodedTags[$0..<$0+metadata.model.tags.count]).argmax()
                
            })
        let tagsByInput = encodedTagsArgmax.map(
        {
            metadata.model.tags[$0.0]
        })
        let inputTagged = zip(encodedInput, tagsByInput) // input:String, tag:String tuple
        let slots = try inputTagged.reduce([:], { (dict, inputTag) in
            var filterName = inputTag.1
            if let prefixIndex = filterName.range(of: "_")?.upperBound {
                filterName = String(filterName.suffix(from: prefixIndex))
            }
            let value = try tokenizer.decodeAndDetokenize([inputTag.0])
            guard let type = intent.slots.filter({ $0.name == filterName }).first?.type else {
                return dict
            }
            return [filterName : Slot(type: type, value: value)]
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
