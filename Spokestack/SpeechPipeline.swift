//
//  SpeechPipeline.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import Dispatch

/**
 This is the primary client entry point to the Spokestack voice input system. It dynamically binds to configured components that implement the pipeline interfaces for reading audio frames and performing speech recognition tasks.
 
 The pipeline may be stopped/restarted any number of times during its lifecycle. While stopped, the pipeline consumes as few resources as possible. The pipeline runs asynchronously on a dedicated thread, so it does not block the caller when performing I/O and speech processing.
 
 When running, the pipeline communicates with the client via delegates that receive events.
 */
@objc public final class SpeechPipeline: NSObject {
    
    // MARK: Public (properties)
    
    /// Pipeline configuration parameters.
    public private (set) var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    public let context: SpeechContext
    
    
    // MARK: Private (properties)
    
    private var stages: [SpeechProcessors]?
    
    // MARK: Initializers
    
    deinit {
        self.context.removeListeners()
        self.stages = nil
    }
    
    /// Initializes a new speech pipeline instance.
    /// - Parameter speechConfiguration: Configuration parameters for the speech pipeline.
    /// - Parameter listeners: Delegate implementations of `SpeechEventListener` that receive speech pipeline events.
    @objc public init(configuration: SpeechConfiguration, listeners: [SpeechEventListener]) {
        self.configuration = configuration
        self.stages = configuration.stages
        self.context = SpeechContext(configuration)
        AudioController.sharedInstance.configuration = configuration
        AudioController.sharedInstance.context = self.context
        super.init()
        listeners.forEach { self.context.setListener($0) }
        self.context.notifyListener(.initialize)
    }
    
    /// MARK: Pipeline control
    
    /**
     Activates speech recognition. The pipeline remains active until the user stops talking or the activation timeout is reached.
     
     Activations have configurable minimum/maximum lengths. The minimum length prevents the activation from being aborted if the user pauses after saying the wakeword (which deactivates the VAD). The maximum activation length allows the activation to timeout if the user doesn't say anything after saying the wakeword.
     
     The wakeword detector can be used in a multi-turn dialogue system. In such an environment, the user is not expected to say the wakeword during each turn. Therefore, an application can manually activate the pipeline by calling `activate` (after a system turn), and the wakeword detector will apply its minimum/maximum activation lengths to control the duration of the activation.
    */
    @objc public func activate() -> Void {
        if !self.context.isActive {
            self.context.isActive = true
            self.context.notifyListener(.activate)
        }
    }
    
    /// Deactivates speech recognition.  The pipeline returns to awaiting either wakeword activation or an explicit `activate` call.
    /// - SeeAlso: `activate`
    @objc public func deactivate() -> Void {
        self.context.isActive = false
        self.context.notifyListener(.deactivate)
    }
    
    /// Starts  the speech pipeline.
    ///
    /// The pipeline starts in a deactivated state, awaiting either a triggered activation from a wakeword or VAD, or an explicit call to `activate`.
    @objc public func start() -> Void {
        
        // initialize stages
        self.stages?.forEach({ stage in
            let stageInstance: SpeechProcessor = {
                switch stage {
                case .vad:
                    return WebRTCVAD(self.configuration, context: self.context)
                case .appleWakeword:
                    return AppleWakewordRecognizer(self.configuration, context: self.context)
                case .tfLiteWakeword:
                    return TFLiteWakewordRecognizer(self.configuration, context: self.context)
                case .appleSpeech:
                    return AppleSpeechRecognizer(self.configuration, context: self.context)
                case .vadTrigger:
                    return VADTrigger(self.configuration, context: self.context)
                }
            }()
            self.context.stageInstances.append(stageInstance)
        })
        
        // notify stages to start
        AudioController.sharedInstance.startStreaming()
        self.context.stageInstances.forEach { stage in
            stage.startStreaming()
        }
        
        // notify listeners of start
        self.context.notifyListener(.start)
    }
    
    /// Stops the speech pipeline.
    ///
    /// All pipeline activity is stopped, and the pipeline cannot be activated until it is `start`ed again.
    @objc public func stop() -> Void {
        self.context.stageInstances.forEach({ stage in
            stage.stopStreaming()
        })
        AudioController.sharedInstance.stopStreaming()
        self.context.notifyListener(.stop)
        self.context.stageInstances = []
    }
}

/**
    Convenience initializer for building a `SpeechPipeline` instance using a pre-configured profile. A pipeline profile encapsulates a series of configuration values tuned for a specific task.
 
    Profiles are not authoritative; they act just like calling a series of methods on a `SpeechPipelineBuilder`, and any configuration properties they set can be overridden by subsequent calls.
 
     Example:
     ```
     // assume that self implements the SpeechEventListener protocol
     let pipeline = SpeechPipelineBuilder()
         .addListener(self)
         .setDelegateDispatchQueue(DispatchQueue.main)
         .useProfile(.tfLiteWakewordAppleSpeech)
         .setProperty("tracing", ".PERF")
         .setProperty("detectModelPath", detectPath)
         .setProperty("encodeModelPath", encodePath)
         .setProperty("filterModelPath", filterPath)
         .build()
     pipeline.start()
     ```
 */
@objc public class SpeechPipelineBuilder: NSObject {
    private let config = SpeechConfiguration()
    private var listeners: [SpeechEventListener] = []
    
    /// Applies configuration from `SpeechPipelineProfiles` to the current builder, returning the modified builder.
    /// - Parameter profile: Name of the profile to apply.
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
    @objc public func useProfile(_ profile: SpeechPipelineProfiles) -> SpeechPipelineBuilder {
        self.config.stages = profile.set
        return self
    }
    
    /// Sets a `SpeechConfiguration` configuration value.
    /// - SeeAlso: `SpeechConfiguration`
    /// - Parameters:
    ///   - key: Configuration property name
    ///   - value: Configuration property name
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
    @objc public func setProperty(_ key: String, _ value: String) -> SpeechPipelineBuilder {
        self.config.setValue(value, forKey: key)
        return self
    }
    
    /// Delegate events will be sent using the specified dispatch queue.
    /// - SeeAlso: `SpeechConfiguration`
    /// - Parameter queue: A `DispatchQueue` instance
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for call chaining.
    @objc public func setDelegateDispatchQueue(_ queue: DispatchQueue) -> SpeechPipelineBuilder {
        self.config.delegateDispatchQueue = queue
        return self
    }
    
    /// Delegate events will be sent to the specified listener.
    /// - Parameter listener: A `SpeechEventListener` instance.
    /// - Returns: An updated instance of `SpeechPipelineBuilder` for instace function  call chaining.
    @objc public func addListener(_ listener: SpeechEventListener) -> SpeechPipelineBuilder {
        self.listeners.append(listener)
        return self
    }
    
    /// Build this configuration into a `SpeechPipeline` instance.
    /// - Returns: A `SpeechPipeline` instance.
    @objc public func build() -> SpeechPipeline {
        return SpeechPipeline(configuration: self.config, listeners: self.listeners)
    }
}
