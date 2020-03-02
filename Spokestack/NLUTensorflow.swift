//
//  NLUTensorflow.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/17/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Combine
import TensorFlowLite

/// A BERT NLU implementation.
@objc public class NLUTensorflow: NSObject, NLUService {
    
    /// Configuration parameters for the NLU.
    @objc public var configuration: SpeechConfiguration
    
    /// An implementation of NLUDelegate to receive NLU events.
    @objc public var delegate: NLUDelegate?
    
    private var interpreter: Interpreter?
    private var tokenizer: BertTokenizer?
    private var metadata: NLUTensorflowMeta?
    private var terminatorToken: Int
    private var paddingToken: Int
    private var maxTokenLength: Int?
    private let decoder = JSONDecoder()
    private var slotParser: NLUTensorflowSlotParser?
    
    internal enum InputTensors: Int, CaseIterable {
        case input
    }
    
    internal enum OutputTensors: Int, CaseIterable {
        case intent
        case tag
    }
    
    /// Initializes an NLU instance.
    /// - Note: An instance initialized this way is expected to use the pub/sub Combine interface, not the delegate interface, when calling `classify`.
    /// - Requires: `SpeechConfiguration.nluVocabularyPath`, `SpeechConfiguration.nluTerminatorTokenIndex`, `SpeechConfiguration.nluPaddingTokenIndex`, `SpeechConfiguration.nluModelPath`, `SpeechConfiguration.nluModelMetadataPath`, and `SpeechConfiguration.nluMaxTokenLength`.
    /// - Parameter configuration: Configuration parameters for the NLU.
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
        self.metadata = try NLUTensorflowMeta(configuration)
        self.slotParser = try NLUTensorflowSlotParser(configuration: configuration, inputMaxTokenLength: inputMaxTokenLength)
    }
    
    /// Initializes an NLU instance.
    /// - Requires: `SpeechConfiguration.nluVocabularyPath`, `SpeechConfiguration.nluTerminatorTokenIndex`, `SpeechConfiguration.nluPaddingTokenIndex`, `SpeechConfiguration.nluModelPath`, `SpeechConfiguration.nluModelMetadataPath`, and `SpeechConfiguration.nluMaxTokenLength`.
    /// - Parameters:
    ///   - delegate: Initializes an NLU instance.
    ///   - configuration: Configuration parameters for the NLU.
    @objc required public init(_ delegate: NLUDelegate, configuration: SpeechConfiguration) throws {
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
            self.metadata = try NLUTensorflowMeta(configuration)
            self.slotParser = try NLUTensorflowSlotParser(configuration: configuration, inputMaxTokenLength: inputMaxTokenLength)
        } catch let error {
            delegate.failure(error: error)
        }
    }
    
    private func initializeInterpreter() throws {
        self.interpreter = try Interpreter(modelPath: self.configuration.nluModelPath)
        try self.interpreter!.allocateTensors()
        if(self.interpreter!.inputTensorCount != InputTensors.allCases.count) || (self.interpreter!.outputTensorCount != OutputTensors.allCases.count) {
            let inputCount = self.interpreter!.inputTensorCount
            let inputCases = InputTensors.allCases.count
            let outputCount = self.interpreter!.outputTensorCount
            let outputCases = OutputTensors.allCases.count
            throw NLUError.model("NLU model provided is not shaped as expected. There are \(inputCount)/\(inputCases) inputs and \(outputCount)/\(outputCases) outputs")
        }
    }
    
    /// Classifies the provided input. The classifciation results are sent to the instance's configured NLUDelegate.
    /// - Parameter utterance: The provided utterance to classify.
    @objc public func classify(utterance: String, context: [String : Any]) -> Void {
        DispatchQueue.main.async {
            let prediction = self.classify(utterance)
            switch prediction {
            case .success(let classification): self.delegate?.classification(result: classification)
            case .failure(let error):
                self.delegate?.failure(error: error)
            }
        }
    }
    
    /// Classifies the provided input. NLUResult is sent to all subscribers.
    /// - Parameter inputs: The provided utterances to classify.
    /// - Warning: `classify` is resource-intensive and should be used with `subscribe(on:)` to ensure it is not blocking the UI thread.
    @available(iOS 13.0, *)
    public func classify(utterances: [String]) -> Publishers.Sequence<[Result<NLUResult, Error>], Never> {
        return utterances.map
            { self.classify($0) }
        .publisher
    }
    
    /// Given an input, provide the model classification result.
    private func classify(_ input: String) -> Result<NLUResult, Error> {
        do {
            guard let model = self.interpreter else {
                throw NLUError.model("NLU model was not initialized.")
            }
            guard let tokenizer = self.tokenizer else {
                throw NLUError.tokenizer("NLU model tokenizer was not initialized.")
            }
            guard let metadata = self.metadata else {
                throw NLUError.metadata("NLU model metadata was not initialized.")
            }
            guard let maxInputTokenLength = self.maxTokenLength else {
                throw NLUError.invalidConfiguration("NLU model maximum input tokens length was not set.")
            }
            guard let parser = self.slotParser else {
                throw NLUError.invalidConfiguration("NLU model parser was not configured.")
            }
            
            // preprocess the model inputs
            // tokenize + encode the input, terminate the utterance with the terminator token, and  pad from the end of the utterance up to the maximum input size (maxInputTokenLength).
            let tokenizedInput = tokenizer.tokenize(input)
            var encodedInput = try tokenizer.encode(tokenizedInput)
            encodedInput.append(self.terminatorToken)
            encodedInput += Array(repeating: self.paddingToken, count: maxInputTokenLength - encodedInput.count)
            
            // downcast the (assumed iOS) default Int64 to match the model's expected Int32 size. This is safe because the model vocabulary code indicies are 32-bit.
            let downcastEncodedInput = encodedInput.map { Int32(truncatingIfNeeded: $0) }
            _ = try downcastEncodedInput
                .withUnsafeBytes { try model.copy(Data($0), toInputAt: InputTensors.input.rawValue) }
            
            // run the model over the provided inputs
            try model.invoke()
            
            // process the model's output
            // extract, decode + detokenize the classified intent, then hydrate the intent result object based on the provided model metadata.
            let encodedIntentsTensor = try model.output(at: OutputTensors.intent.rawValue)
            let encodedIntents = encodedIntentsTensor.data.toArray(type: Float32.self, count: encodedIntentsTensor.data.count/4)
            let intentsArgmax = encodedIntents.argmax()
            if intentsArgmax.0 > metadata.model.intents.count {
                throw NLUError.model("NLU model intent classification failed because the model classification output did not match the model metadata.")
            }
            let intent = metadata.model.intents[intentsArgmax.0]
            
            // extract, decode + detokenize the classified tags, then hydrate the result slots based on the provided model metadata.
            let encodedTagTensor = try model.output(at: OutputTensors.tag.rawValue)
            let encodedTags = encodedTagTensor.data.toArray(type: Float32.self, count: encodedTagTensor.data.count/4)
            // the posteriors for the tags are grouped by the number of model metadata tags, so stride through them calculating the argmax for each stride.
            let encodedTagsArgmax = stride(from: 0,
                                           to: encodedTags.count,
                                           by: metadata.model.tags.count)
                .map { Array(encodedTags[$0..<$0+metadata.model.tags.count]).argmax() }
            // decode the tags according to the model metatadata index
            let tagsByInput = encodedTagsArgmax.map { metadata.model.tags[$0.0] }
            // zip up the input + tags, since their ordering corresponds
            let taggedInput = zip(tagsByInput, tokenizedInput) // tag:String, input:String tuple
            // hyrdate Slot objects according to the zipped input + tag
            let slots = try parser.parse(taggedInput: taggedInput, intent: intent)
            
            // return the classification result
            return .success(NLUResult(utterance: input, intent: intent.name, confidence: intentsArgmax.1, slots: slots))
        } catch let error {
            return .failure(error)
        }
    }
}
