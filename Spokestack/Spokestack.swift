//
//  Spokestack.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 9/23/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// This class combines all Spokestack modules into a single component to provide a unified interface to the library's ASR, NLU, and TTS features. Like the individual modules, it is configurable using a fluent builder pattern, but it provides a default configuration; only a few parameters are required from the calling application, and those only for specific features noted in the documentation for the builder's methods.
///
/// The default configuration of this class assumes that the client application wants to use all of Spokestack's features, regardless of their implied dependencies or required configuration. If a prerequisite is missing at build time, the individual module may throw an error when called.
///
/// This class will run in the context of the caller. The subsystems themselves may use the configured dispatch queues where appropriate to perform intensive tasks.
///
/// - SeeAlso:
/// `SpeechPipeline`, `NLUTensorflow`, `TextToSpeech`
///
@objc public class Spokestack: NSObject {
    /// This is the client entry point to the Spokestack voice input system.
    @objc public var pipeline: SpeechPipeline
    /// This is the client entry point for the Spokestack Text to Speech (TTS) system.
    @objc public var tts: TextToSpeech
    /// This is the client entry point for the Spokestack BERT NLU implementation.
    @objc public var nlu: NLUTensorflow
    /// Maintains global state for the speech pipeline.
    @objc public var context: SpeechContext
    /// Configuration properties for Spokestack modules.
    @objc public var configuration: SpeechConfiguration
    
    private var delegates: [SpokestackDelegate]
    private var editor: TranscriptEditor?

    /// This constructor is intended for use only by the `SpokestackBuilder`.
    /// - Parameters:
    ///   - delegates: Delegate implementations of `SpokestackDelegate` that receive Spokestack module events.
    ///   - configuration: Configuration properties for Spokestack modules.
    ///   - pipeline: An initialized SpeechPipeline for the client to access.
    ///   - nlu: An initialized NLUTensorflow for the client to access.
    ///   - tts: An initialized TextToSpeech for the client to access.
    @objc internal init(delegates: [SpokestackDelegate], configuration: SpeechConfiguration, pipeline: SpeechPipeline, nlu: NLUTensorflow, tts: TextToSpeech, editor: TranscriptEditor?) {
        self.delegates = delegates
        self.configuration = configuration
        self.pipeline = pipeline
        self.context = pipeline.context
        self.nlu = nlu
        self.tts = tts
        self.editor = editor
        super.init()
    }
}

extension Spokestack: SpokestackDelegate {
    
    /// A required function for `SpokestackDelegate` implementors
    /// - Parameter error: An error sent from a Spokestack module.
    public func failure(error: Error) {}
    
    /// An event receiver used to fulfill automatic classification configuration.
    /// - Parameter result: Global state for the speech pipeline.
    public func didRecognize(_ result: SpeechContext) {
        self.configuration.automaticallyClassifyTranscript ?
            self.nlu.classify(utterance: self.editor?.editTranscript(transcript: result.transcript) ?? result.transcript) : nil
    }
}

/// Fluent builder interface for configuring Spokestack.
/// - Example: *using all the builder functions*
/// ```
/// let spokestack = try! SpokestackBuilder()
///   .addDelegate(self)
///   .usePipelineProfile(.vadTriggerAppleSpeech)
///   .setConfiguration(SpeechConfiguration)
///   .setProperty("tracing", Trace.Level.DEBUG)
///   .setDelegateDispatchQueue(DispatchQueue.main)
///   .build()
///```
///
/// - SeeAlso: `Spokestack`
@objc public class SpokestackBuilder: NSObject {
    private var delegates: [SpokestackDelegate] = []
    private var config = SpeechConfiguration()
    private var context: SpeechContext
    private var pipelineProfile: SpeechPipelineProfiles = .tfLiteWakewordAppleSpeech
    private var editor: TranscriptEditor?

    /// Create a Spokestack builder with a default configuration.
    @objc public override init() {
        self.context = SpeechContext(self.config)
        super.init()
    }
    
    /// Delegate events will be sent to the specified listener.
    /// - Parameter listener: A `SpokestackDelegate` instance.
    /// - Returns: An updated instance of `SpokestackBuilder`
    @objc public func addDelegate(_ delegate: SpokestackDelegate) -> SpokestackBuilder {
        self.delegates.append(delegate)
        return self
    }
    
    /// Applies configuration from `SpeechPipelineProfiles` to the current builder, returning the modified builder.
    /// - Parameter profile: Name of the profile to apply.
    /// - Returns: An updated instance of `SpokestackBuilder` for call chaining.
    @objc public func usePipelineProfile(_ profile: SpeechPipelineProfiles) -> SpokestackBuilder {
        self.pipelineProfile = profile
        return self
    }
    
    /// Sets a `SpeechConfiguration` configuration value.
    /// - SeeAlso: `SpeechConfiguration`
    /// - Parameters:
    ///   - key: Configuration property name
    ///   - value: Configuration property value
    /// - Note: "tracing" key must have a value of `Trace.Level`, eg `Trace.Level.DEBUG`.
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
    @objc public func setProperty(_ key: String, _ value: Any) -> SpokestackBuilder {
        switch key {
        case "tracing":
            guard let t = value as? Trace.Level else {
                break
            }
            self.config.setValue(t.rawValue, forKey: key)
        default:
            self.config.setValue(value, forKey: key)
        }
        return self
    }
    
    /// Replaces the default speech configuration with the specified configuration.
    ///
    /// - Warning: All preceeding `setProperty` calls will be erased by setting the configuration explicitly.
    /// - Parameter config: An instance of SpeechConfiguration that the pipeline will use.
    @objc public func setConfiguration(_ config: SpeechConfiguration) -> SpokestackBuilder {
        self.config = config
        return self
    }
    
    /// Delegate events will be sent using the specified dispatch queue.
    /// - SeeAlso: `SpeechConfiguration`
    /// - Parameter queue: A `DispatchQueue` instance
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
    @objc public func setDelegateDispatchQueue(_ queue: DispatchQueue) -> SpokestackBuilder {
        self.config.delegateDispatchQueue = queue
        return self
    }
    
    /// Sets a transcript editor used to alter ASR transcripts before they are classified by the NLU subsystem.
    ///
    /// If a transcript editor is set, registered listeners will still receive the `didRecognize` event from the speech pipeline with the unedited transcripts, but the editor will automatically run on those transcripts before the NLU module, operates on them. Thus, the `utterance` inside the `NLUResult` returned by classification will reflect the edited version of the transcript.
    ///
    /// This can be used to alter ASR results that frequently contain a spelling for a homophone that's incorrect for the domain; for example, an app used to summon a genie whose ASR transcripts tend to contain "Jen" instead of "djinn".
    /// - Note: Transcript editors are _not_ run automatically on inputs to the `classify(string:)` convenience method.
    /// - Parameter editor:  A transcript editor used to alter ASR results before NLU classification.
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
    @objc public func setTranscriptEditor(_ editor: TranscriptEditor) -> SpokestackBuilder {
        self.editor = editor
        return self
    }
    
    /// Build this configuration into a `Spokestack` instance.
    /// - Throws: An `NLUError` if the NLU module was unable to build.
    /// - Returns: An instance of `Spokestack`.
    @objc public func build() throws -> Spokestack {
        let pipelineBuilder = SpeechPipelineBuilder.init()
        self.delegates.forEach { let _ = pipelineBuilder.addListener($0) }
        let pipeline = try pipelineBuilder
            .useProfile(self.pipelineProfile)
            .setConfiguration(self.config)
            .build()
        let tts = TextToSpeech(self.delegates, configuration: self.config)
        let nlu = try NLUTensorflow(self.delegates, configuration: self.config)
        let spokestack = Spokestack(delegates: self.delegates, configuration: self.config, pipeline: pipeline, nlu: nlu, tts: tts, editor: self.editor)
        if self.config.automaticallyClassifyTranscript {
            pipeline.context.addListener(spokestack)
        }
        return spokestack
    }
}
