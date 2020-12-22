//
//  Error.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Errors thrown by `AudioController` during `startStreaming` and `stopStreaming`.
/// - SeeAlso: AudioController
public enum AudioError: Error, Equatable, LocalizedError {
    /// An audio unit system error
    case audioSessionSetup(String)
    /// An audio controller error
    case audioController(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .audioSessionSetup(message), let .audioController(message):
            return message
        }
    }
}

/// Errors thrown by the `SpeechPipeline`.
/// - SeeAlso: SpeechPipeline
public enum SpeechPipelineError: Error, Equatable, LocalizedError {
    /// The SpeechPipeline internal buffers entered an illegal state.
    case illegalState(String)
    /// The SpeechPipeline received a response that was invalid.
    case invalidResponse(String)
    /// The SpeechPipeline encountered a failure in a component.
    case failure(String)
    /// A pipeline component attempted to send an error to SpeechContext's listeners without first setting the SpeechContext.error property.
    case errorNotSet(String)
    /// The settings provided to the pipeline builder were not sufficient to create a pipeline.
    case incompleteBuilder(String)
    /// The api key provided is not valid.
    case apiKey(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .illegalState(message), let .invalidResponse(message), let .failure(message), let .errorNotSet(message), let .incompleteBuilder(message), let .apiKey(message):
            return message
        }
    }
}

/// Errors thrown by the Voice Activity Detector.
public enum VADError: Error, Equatable, LocalizedError {
    /// The VAD instance was configured with incompatible settings.
    case invalidConfiguration(String)
    /// The VAD instance was unable to initialize.
    case initialization(String)
    /// The VAD instance encountered an error during the processing of the audio frame.
    case processing(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message), let .initialization(message), let .processing(message):
            return message
        }
    }
}

/// Errors thrown by  command models.
/// - SeeAlso: `TFLiteWakewordRecognizer`, `TFLiteKeywordRecognizer`
public enum CommandModelError: Error, Equatable, LocalizedError {
    /// The command recognizer was unable to configure the recognizer model(s).
    case model(String)
    /// The rcommand ecognizer encountered an error during the processing of the audio frame.
    case process(String)
    /// The command recognizer encountered an error during the configuration or running of the filter model.
    case filter(String)
    /// The command recognizer encountered an error during the configuration or running of the encode model.
    case encode(String)
    /// The command recognizer encountered an error during the configuration or running of the detect model.
    case detect(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .model(message), let .process(message), let .filter(message), let .encode(message), let .detect(message):
            return message
        }
    }
}

/// Errors thrown by RingBuffer instances.
enum RingBufferStateError: Error, Equatable, LocalizedError {
    // The RingBuffer instance entered an illegal state during a `read` or `write`.
    case illegalState(message: String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .illegalState(message):
            return message
        }
    }
}

/// Errors thrown by TTS instances.
enum TextToSpeechErrors: Error, Equatable, LocalizedError {
    /// The synthesize response was missing data.
    case deserialization(String)
    /// The synthesize request was unable to be serialized.
    case serialization(String)
    /// The api key provided is not valid.
    case apiKey(String)
    /// The speak command could not be executed.
    case speak(String)
    /// The input format was not specified correctly.
    case format(String)
    /// The input voice was not specified correctly.
    case voice(String)
    /// The HTTP reponse status code was not OK.
    case httpStatusCode(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .deserialization(message), let .serialization(message), let .apiKey(message), let .speak(message), let .format(message), let .voice(message), let .httpStatusCode(message):
            return message
        }
    }
}

/// Errors thrown by a Tokenizer instance.
enum TokenizerError: Error, Equatable, LocalizedError {
    /// The text to tokenize is too long.
    case tooLong(String)
    /// The tokenizer instance was configured with incompatible settings.
    case invalidConfiguration(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .tooLong(message), let .invalidConfiguration(message):
            return message
        }
    }
}

/// Errors thrown by an NLUService instance.
public enum NLUError: Error, Equatable, LocalizedError {
    /// The NLUService instance was configured with incompatible settings.
    case invalidConfiguration(String)
    /// The NLUService tokenizer encountered an error.
    case tokenizer(String)
    /// The model provided to the NLUService instance encountered an error.
    case model(String)
    /// There was a problem with the metadata provided to the NLUService instance.
    case metadata(String)
    
    /// `LocalizedError` implementation so that `localizedDescription` isn't an enum index.
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(message), let .tokenizer(message), let .model(message), let .metadata(message):
            return message
        }
    }
}
