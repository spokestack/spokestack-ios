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
 
 ```
 // assume that self implements the SpeechEventListener and PipelineDelegate protocols
 let pipeline = SpeechPipeline(SpeechProcessors.appleSpeech.processor,
 speechConfiguration: SpeechConfiguration(),
 speechDelegate: self,
 wakewordService: SpeechProcessors.appleWakeword.processor,
 pipelineDelegate: self)
 pipeline.start()
 ```
 */
@objc public final class SpeechPipeline: NSObject {
    
    // MARK: Public (properties)
    
    /// Pipeline configuration parameters.
    public private (set) var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    public let context: SpeechContext = SpeechContext()
    
    
    // MARK: Private (properties)
    
    private var stages: [SpeechProcessors]?
    
    // MARK: Initializers
    
    deinit {
        self.context.listeners = []
        self.stages = nil
    }
    
    /// Initializes a new speech pipeline instance.
    /// - Parameter speechConfiguration: Configuration parameters for the speech pipeline.
    /// - Parameter listeners: Client implementations of `SpeechEventListener`.
    @objc public init(configuration: SpeechConfiguration, listeners: [SpeechEventListener]) {
        self.configuration = configuration
        self.stages = configuration.stages
        self.context.listeners = listeners
        AudioController.sharedInstance.configuration = configuration
        super.init()
        
        // initialization finished, emit the corresponding event
        self.configuration.delegateDispatchQueue.async {
            self.context.listeners.forEach({ listener in
                listener.didInit()
            })
        }
    }
    
    /// MARK: Pipeline control
    
    /**
     Activates speech recognition. The pipeline remains active until the user stops talking or the activation timeout is reached.
     
     Activations have configurable minimum/maximum lengths. The minimum length prevents the activation from being aborted if the user pauses after saying the wakeword (which deactivates the VAD). The maximum activation length allows the activation to timeout if the user doesn't say anything after saying the wakeword.
     
     The wakeword detector can be used in a multi-turn dialogue system. In such an environment, the user is not expected to say the wakeword during each turn. Therefore, an application can manually activate the pipeline by calling `activate` (after a system turn), and the wakeword detector will apply its minimum/maximum activation lengths to control the duration of the activation.
     
     - SeeAlso: `wakeActiveMin`, `wakeActiveMax`
     */
    @objc public func activate() -> Void {
        self.context.isActive = true
    }
    
    /// Deactivates speech recognition.  The pipeline returns to awaiting either wakeword activation or an explicit `activate` call.
    /// - SeeAlso: `activate`
    @objc public func deactivate() -> Void {
        self.context.isActive = false
    }
    
    /// Starts  the speech pipeline.
    ///
    /// The pipeline starts in a deactivated state, awaiting either a wakeword activation or an explicit call to `activate`.
    @objc public func start() -> Void {
        
        // initialize stages
        self.stages?.forEach({ stage in
            let stageInstance: SpeechProcessor = {
                switch stage {
                case .vad:
                    return WebRTCVAD(self.configuration)
                case .appleWakeword:
                    return AppleWakewordRecognizer(self.configuration)
                case .tfLiteWakeword:
                    return TFLiteWakewordRecognizer(self.configuration)
                case .appleSpeech:
                    return AppleSpeechRecognizer(self.configuration)
                }
            }()
            self.context.stageInstances.append(stageInstance)
        })
        
        // notify stages to start
        AudioController.sharedInstance.startStreaming(context: self.context)
        self.context.stageInstances.forEach { stage in
            stage.startStreaming(context: self.context)
        }
        
        // notify listeners of start
        self.context.isStarted = true
        self.context.listeners.forEach({ listener in
            listener.didStart()
        })
    }
    
    /// Stops the speech pipeline.
    ///
    /// All pipeline activity is stopped, and the pipeline cannot be activated until it is `start`ed again.
    @objc public func stop() -> Void {
        self.context.isStarted = false
        self.context.stageInstances.forEach({ stage in
            stage.stopStreaming(context: self.context)
        })
        AudioController.sharedInstance.stopStreaming(context: self.context)
        self.context.listeners.forEach({ listener in
            listener.didStop()
        })
        self.context.stageInstances = []
    }
}
