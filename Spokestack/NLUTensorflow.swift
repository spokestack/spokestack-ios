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

/** This is the client entry point for the Spokestack BERT NLU implementation. This class provides a classification interface for deriving intents and slots from a natural language utterance. When initialized, the TTS system communicates with the client via either a delegate that receive events or the publisher-subscriber pattern.

 ```
 // assume that self implements the `SpokestackDelegate` protocol
 let nlu = try! NLUTensorflow(self, configuration: configuration)
 nlu.classify(utterance: "I can't turn that light in the room on for you, Dave", context: [:])
 ```
 
    Using the NLUTensorflow class requires the providing a number of `SpeechConfiguration` variables, all prefixed with `nlu`. The most important are the `nluVocabularyPath`, `nluModelPath`, and the `nluModelMetadataPath`.
 */
@objc public class NLUTensorflow: NSObject, NLUService {
    
    /// Configuration parameters for the NLU.
    @objc public var configuration: SpeechConfiguration
    
    /// An implementation of NLUDelegate to receive NLU events.
    @objc public var delegates: [SpokestackDelegate] = []
    
    private var interpreter: Interpreter?
    private var tokenizer: BertTokenizer?
    private var metadata: NLUTensorflowMeta?
    private var terminatorToken: Int
    private var paddingToken: Int
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
        try self.configure()
    }
    
    /// Initializes an NLU instance.
    /// - Requires: `SpeechConfiguration.nluVocabularyPath`, `SpeechConfiguration.nluTerminatorTokenIndex`, `SpeechConfiguration.nluPaddingTokenIndex`, `SpeechConfiguration.nluModelPath`, `SpeechConfiguration.nluModelMetadataPath`, and `SpeechConfiguration.nluMaxTokenLength`.
    /// - Parameters:
    ///   - delegate: Delegate that receives NLU events.
    ///   - configuration: Configuration parameters for the NLU.
    @objc required public init(_ delegates: [SpokestackDelegate], configuration: SpeechConfiguration) throws {
        self.delegates = delegates
        self.configuration = configuration
        self.terminatorToken = configuration.nluTerminatorTokenIndex
        self.paddingToken = configuration.nluPaddingTokenIndex
        do {
            super.init()
            try self.configure()
        } catch let error {
            self.configuration.delegateDispatchQueue.async {
                delegates.forEach { $0.failure(error: error) }
            }
        }
    }
    
    private func configure() throws {
        try self.initializeInterpreter()
        guard let model = self.interpreter else {
            throw NLUError.model("NLU model was not initialized.")
        }
        let inputTensor = try model.input(at: InputTensors.input.rawValue)
        self.configuration.nluMaxTokenLength = inputTensor.shape.dimensions[1]
        self.tokenizer = try BertTokenizer(configuration)
        self.metadata = try NLUTensorflowMeta(configuration)
        self.slotParser = NLUTensorflowSlotParser()
        // warm up the interpreter to speed up a subsequent client call
        let dim = [Int32](repeating: Int32(0), count: self.configuration.nluMaxTokenLength)
        _ = try dim.withUnsafeBytes { try self.interpreter!.copy(Data($0), toInputAt: InputTensors.input.rawValue) }
        _ = try self.interpreter!.invoke()
    }
    
    private func initializeInterpreter() throws {
        self.interpreter = try Interpreter(modelPath: self.configuration.nluModelPath)
        try self.interpreter!.allocateTensors()
        let inputCount = self.interpreter!.inputTensorCount
        let inputCases = InputTensors.allCases.count
        let outputCount = self.interpreter!.outputTensorCount
        let outputCases = OutputTensors.allCases.count
        if (inputCount != inputCases) || (outputCount != outputCases) {
            throw NLUError.model("NLU model provided is not shaped as expected. There are \(inputCount)/\(inputCases) inputs and \(outputCount)/\(outputCases) outputs")
        }
    }
    
    private func dispatch(_ handler: @escaping (SpokestackDelegate) -> Void) {
        self.configuration.delegateDispatchQueue.async {
            self.delegates.forEach(handler)
        }
    }

    /// Classifies the provided input. The classification results are sent to the instance's configured NLUDelegate.
    /// - Parameter utterance: The provided utterance to classify.
    /// - Parameter context: Context for NLU operations
    @objc public func classify(utterance: String, context: [String : Any] = [:]) -> Void {
        DispatchQueue.global(qos: .userInitiated).async {
            let prediction = self.classify(utterance)
            switch prediction {
            case .success(let classification):
                self.dispatch { $0.classification?(result: classification) }
            case .failure(let error):
                self.dispatch { $0.failure(error: error) }
            }
        }
    }
    
    /// Classifies the provided input. NLUResult is sent to all subscribers.
    /// - Parameter utterances: A list of utterances to classify
    /// - Parameter context: Context for NLU operations
    /// - Warning: `classify` is resource-intensive and should be used with `subscribe(on:)` to ensure it is not blocking the UI thread.
    /// - Returns: `AnyPublisher<[NLUResult], Error>`
    @available(iOS 13.0, *)
    public func classify(utterances: [String], context: [String : Any] = [:]) -> Publishers.Sequence<[Result<NLUResult, Error>], Never> {
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
                throw NLUError.tokenizer("NLU tokenizer was not initialized.")
            }
            guard let metadata = self.metadata else {
                throw NLUError.metadata("NLU model metadata was not initialized.")
            }
            
            // preprocess the model inputs
            // tokenize + encode the input, terminate the utterance with the terminator token, and  pad from the end of the utterance up to the maximum input size (maxInputTokenLength).
            let encodedInput = try tokenizer.encode(text: input)
            var encodedTokens = encodedInput.encoded
            if encodedTokens.count > self.configuration.nluMaxTokenLength {
                throw TokenizerError.tooLong("This input is represented by (\(encodedTokens.count) tokens. The maximum number of tokens the model can classify is \(self.configuration.nluMaxTokenLength).")
            }
            encodedTokens
                += [self.terminatorToken]
                + Array(repeating: self.paddingToken, count: self.configuration.nluMaxTokenLength - encodedTokens.count - 1)
            Trace.trace(Trace.Level.DEBUG, message: "classify encoded tokens: \(encodedTokens)", config: self.configuration, delegates: self.delegates, caller: self)
            // downcast the (assumed iOS) default Int64 to match the model's expected Int32 size. This is safe because the model vocabulary code indicies are 32-bit.
            let downcastEncodedInput = encodedTokens.map { Int32(truncatingIfNeeded: $0) }
            _ = try downcastEncodedInput
                .withUnsafeBytes { try model.copy(Data($0), toInputAt: InputTensors.input.rawValue) }
            
            // run the model over the provided inputs
            try model.invoke()
            
            // process the model's output
            
            // get the intent
            let encodedIntentsTensor = try model.output(at: OutputTensors.intent.rawValue)
            let intent = try self.extractIntent(intentTensor: encodedIntentsTensor, metadata: metadata)
            
            // get the slots
            let encodedTagTensor = try model.output(at: OutputTensors.tag.rawValue)
            let slots = try self.extractSlots(slotsTensor: encodedTagTensor, metadata: metadata, encodedInput: encodedInput, intent: intent, tokenizer: tokenizer)
            // return the classification result
            return .success(NLUResult(utterance: input, intent: intent.name, confidence: intent.confidence ?? 0.0, slots: slots))
        } catch let error {
            return .failure(error)
        }
    }
    
    // extract, decode + detokenize the classified intent, then hydrate the intent result object based on the provided model metadata.
    private func extractIntent(intentTensor: Tensor, metadata: NLUTensorflowMeta) throws -> NLUTensorflowIntent {
        let encodedIntents = intentTensor.data.toArray(type: Float32.self, count: intentTensor.data.count/4)
        let intentsArgmax = encodedIntents.argmax()
        if intentsArgmax.0 > metadata.model.intents.count {
            throw NLUError.model("NLU intent classification failed because the model classification output did not match the model metadata.")
        }
        var intent = metadata.model.intents[intentsArgmax.0]
        intent.confidence = intentsArgmax.1
        Trace.trace(Trace.Level.DEBUG, message: "classify intent: \(intent.name)", config: self.configuration, delegates: self.delegates, caller: self)
        return intent
    }
    
    // extract, decode + detokenize the classified tags, then hydrate the result slots based on the provided model metadata.
    private func extractSlots(slotsTensor: Tensor, metadata: NLUTensorflowMeta, encodedInput: EncodedTokens, intent: NLUTensorflowIntent, tokenizer: BertTokenizer) throws -> [String : Slot]? {
        guard let parser = self.slotParser else {
            throw NLUError.invalidConfiguration("NLU slot parser was not configured.")
        }
        let encodedTags = slotsTensor.data.toArray(type: Float32.self, count: slotsTensor.data.count/4)
        // the posteriors for the tags are grouped by the number of model metadata tags, so stride through them calculating the argmax for each stride.
        let encodedTagsArgmax = stride(from: 0,
                                       to: encodedTags.count,
                                       by: metadata.model.tags.count)
            .map { Array(encodedTags[$0..<$0+metadata.model.tags.count]).argmax() }
        Trace.trace(Trace.Level.DEBUG, message: "classify argmaxes: \(encodedTagsArgmax)", config: self.configuration, delegates: self.delegates, caller: self)
        // decode the tags according to the model metadata index
        let tagsByInput = encodedTagsArgmax.map { metadata.model.tags[$0.0] }
        Trace.trace(Trace.Level.DEBUG, message: "classify tags: \(tagsByInput)", config: self.configuration, delegates: self.delegates, caller: self)
        // hydrate Slot objects according to the tag
        return try parser.parse(tags: tagsByInput, intent: intent, encoder: tokenizer, encodedTokens: encodedInput)
    }
}
