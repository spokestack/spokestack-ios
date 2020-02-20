//
//  TensorflowNLU.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/17/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Combine
import TensorFlowLite

/// A BERT NLU implementation.
@objc public class TensorflowNLU: NSObject, NLUService {
    
    /// Configuration parameters for the NLU.
    @objc public var configuration: SpeechConfiguration
    
    /// An implementation of NLUDelegate to receive NLU events.
    @objc public var delegate: NLUDelegate?
    
    private var interpreter: Interpreter?
    private var tokenizer: BertTokenizer?
    private var metadata: NLUModelMeta?
    private var terminatorToken: Int
    private var paddingToken: Int
    private var maxTokenLength: Int?
    private let decoder = JSONDecoder()
    private var slotParser: NLUSlotParser?
    
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
        self.metadata = try NLUModelMeta(configuration)
        self.slotParser = try NLUSlotParser(configuration: configuration, inputMaxTokenLength: inputMaxTokenLength)
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
            self.metadata = try NLUModelMeta(configuration)
            self.slotParser = try NLUSlotParser(configuration: configuration, inputMaxTokenLength: inputMaxTokenLength)
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
    
    /// Classifies the provided input. The classifciation results are sent to the instance's configured NLUDelegate.
    /// - Parameter input: The NLUInput to classify.
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
    /// - Parameter inputs: The NLUInput to classify.
    /// - Warning: `classify` is resource-intensive and should be used with `subscribe(on:)` to ensure it is not blocking the UI thread.
    @available(iOS 13.0, *)
    public func classify(inputs: [String]) -> Publishers.Sequence<[Result<NLUResult, Error>], Never> {
        return inputs.map
            { self.classify($0) }
        .publisher
        //return AnyPublisher<[Prediction], Error>(try inputs.map { try self.predict($0) as Prediction })
        //return Publishers.First(upstream: Just([Prediction(intent: "", confidence: 0.0, slots: [:])]).setFailureType(to: Error.self)).eraseToAnyPublisher()
    }
    
    private func classify(_ input: String) -> Result<NLUResult, Error> {
        do {
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
            guard let parser = self.slotParser else {
                throw NLUError.invalidConfiguration("No slot parser was set for this model.")
            }
            
            // preprocess the model inputs
            //  tokenize + encode the input, terminate the utterance with the terminator token, and  pad from the end of the utterance up to the expected input size (128 32-bit ints)
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
                throw NLUError.model("NLU model returned an intent value outside the expected range.")
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
            // zip up the input + tags, since their ordering corresponds. this also effectivly truncates the tag posteriors by the input size, ignoring all posteriors outside the input length.
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
