//
//  Spokestack.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 9/23/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// <#Description#>
@objc public class Spokestack: NSObject {
    /// <#Description#>
    @objc public var pipeline: SpeechPipeline?
    /// <#Description#>
    @objc public var tts: TextToSpeech?
    /// <#Description#>
    @objc public var nlu: NLUTensorflow?
    /// <#Description#>
    @objc public var context: SpeechContext?
    /// <#Description#>
    @objc public var configuration: SpeechConfiguration
    
    private var delegates: [SpokestackDelegate]
    
    /// <#Description#>
    /// - Parameters:
    ///   - delegates: <#delegates description#>
    ///   - configuration: <#configuration description#>
    @objc public init(delegates: [SpokestackDelegate], configuration: SpeechConfiguration) {
        self.delegates = delegates
        self.configuration = configuration
        super.init()
    }
}

/// <#Description#>
@objc public class SpokestackBuilder: NSObject {
    private var pipeline: SpeechPipeline?
    private var tts: TextToSpeech?
    private var nlu: NLUTensorflow?
    private var delegates: [SpokestackDelegate] = []
    private var config = SpeechConfiguration()
    private var context: SpeechContext
    private var pipelineProfile: SpeechPipelineProfiles = .tfLiteWakewordAppleSpeech
    
    /// <#Description#>
    @objc public override init() {
        self.context = SpeechContext(self.config)
        super.init()
    }
    
    /// Applies configuration from `SpeechPipelineProfiles` to the current builder, returning the modified builder.
    /// - Parameter profile: Name of the profile to apply.
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
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
    
    /// Build this configuration into a `Spokestack` instance.
    /// - Throws: An `NLUError` if the NLU module was unable to build.
    /// - Returns: An instance of `Spokestack`.
    @objc public func build() throws -> Spokestack {
        let pipelineBuilder = SpeechPipelineBuilder.init()
        self.delegates.forEach { let _ = pipelineBuilder.addListener($0) }
        self.pipeline = try pipelineBuilder
            .useProfile(self.pipelineProfile)
            .setConfiguration(self.config)
            .build()
        self.tts = TextToSpeech(self.delegates, configuration: self.config)
        self.nlu = try NLUTensorflow(self.delegates, configuration: self.config)
        let spokestack = Spokestack(delegates: self.delegates, configuration: self.config)
        spokestack.pipeline = self.pipeline
        spokestack.nlu = self.nlu
        spokestack.tts = self.tts
        return spokestack
    }
}
