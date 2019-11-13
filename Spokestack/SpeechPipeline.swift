//
//  SpeechPipeline.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

/**
 This is the primary client entry point to the SpokeStack framework. It dynamically binds to configured components that implement the pipeline interfaces for reading audio frames and performing speech recognition tasks.

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
 
 - Warning: All calls to delegate event handlers are made in the context of the pipeline's thread, so event handlers should not perform blocking operations, and they should use message passing when communicating with UI components, etc.
*/
@objc public final class SpeechPipeline: NSObject {
    
    // MARK: Public (properties)
    
    /// Pipeline configuration parameters.
    public private (set) var speechConfiguration: SpeechConfiguration?
    /// Delegate that receives speech events.
    public weak var speechDelegate: SpeechEventListener?
    /// Delegate that receives pipeline events.
    public private (set) var pipelineDelegate: PipelineDelegate?
    /// Global state for the speech pipeline.
    public let context: SpeechContext = SpeechContext()
    
    
    // MARK: Private (properties)
    
    private var speechRecognizerService: SpeechProcessor
    private var wakewordRecognizerService: SpeechProcessor
    
    // MARK: Initializers
    
    deinit {
        speechRecognizerService.delegate = nil
        wakewordRecognizerService.delegate = nil
    }
    
    /// Initializes a new speech pipeline instance with reasonable defaults for configuration, wakeword, and asr recognizers.
    /// - Parameter speechDelegate: An implementation of `SpeechEventListener`.
    /// - Parameter pipelineDelegate: An implementation of `PipelineDelegate`.
    @objc public init(_ speechDelegate: SpeechEventListener,
                      pipelineDelegate: PipelineDelegate) {
        let c = SpeechConfiguration()
        self.speechConfiguration = SpeechConfiguration()
        self.speechDelegate = speechDelegate
        
        self.speechRecognizerService = SpeechProcessors.appleSpeech.processor
        /// order is important: set the delegate first so that configuration errors/tracing can be sent back
        self.speechRecognizerService.delegate = self.speechDelegate
        self.speechRecognizerService.configuration = c
        self.wakewordRecognizerService = SpeechProcessors.appleWakeword.processor
        /// see previous comment
        self.wakewordRecognizerService.delegate = self.speechDelegate
        self.wakewordRecognizerService.configuration = c
        
        AudioController.sharedInstance.configuration = c
        
        self.pipelineDelegate = pipelineDelegate
        AudioController.sharedInstance.pipelineDelegate = self.pipelineDelegate
        self.pipelineDelegate?.didInit()
    }
    
    /// Initializes a new speech pipeline instance.
    /// - Parameter speechService: An implementation of `SpeechProcessor`.
    /// - Parameter speechConfiguration: Configuration parameters for the speech pipeline.
    /// - Parameter speechDelegate: An implementation of `SpeechEventListener`.
    /// - Parameter wakewordService: An implementation of `SpeechProcessor`.
    /// - Parameter pipelineDelegate: An implementation of `PipelineDelegate`.
    @objc public init(_ speechService: SpeechProcessor,
                      speechConfiguration: SpeechConfiguration,
                      speechDelegate: SpeechEventListener,
                      wakewordService: SpeechProcessor,
                      pipelineDelegate: PipelineDelegate) {
        self.speechConfiguration = speechConfiguration
        self.speechDelegate = speechDelegate
        
        self.speechRecognizerService = speechService
        /// order is important: set the delegate first so that configuration errors/tracing can be sent back
        self.speechRecognizerService.delegate = self.speechDelegate
        self.speechRecognizerService.configuration = speechConfiguration
        self.wakewordRecognizerService = wakewordService
        /// see previous comment
        self.wakewordRecognizerService.delegate = self.speechDelegate
        self.wakewordRecognizerService.configuration = speechConfiguration
        
        AudioController.sharedInstance.configuration = speechConfiguration
        
        self.pipelineDelegate = pipelineDelegate
        AudioController.sharedInstance.pipelineDelegate = self.pipelineDelegate
        self.pipelineDelegate?.didInit()
    }
    
    /// Checks the status of the delegates provided in the constructor.
    ///
    /// - Remarks: Verifies that a strong reference to the delegates is being held.
    /// - SeeAlso: `setDelegates`
    /// - Returns: whether the delegate properties are currently set
    @objc public func status() -> Bool {
        guard
            let _ = self.speechDelegate,
            let _ = self.pipelineDelegate
        else {
            return false
        }
        return true
    }
    
    /// Sets the property for the`SpeechEventListener` delegate .
    /// - Parameter speechDelegate: a `SpeechEventListener` protocol implementer.
    @objc public func setDelegates(_ speechDelegate: SpeechEventListener) -> Void {
        self.speechDelegate = speechDelegate
        self.speechRecognizerService.delegate = self.speechDelegate
        self.wakewordRecognizerService.delegate = self.speechDelegate
    }
    
    /**
     Activates speech recognition. The pipeline remains active until the user stops talking or the activation timeout is reached.
 
     Activations have configurable minimum/maximum lengths. The minimum length prevents the activation from being aborted if the user pauses after saying the wakeword (which deactivates the VAD). The maximum activation length allows the activation to timeout if the user doesn't say anything after saying the wakeword.
    
    The wakeword detector can be used in a multi-turn dialogue system. In such an environment, the user is not expected to say the wakeword during each turn. Therefore, an application can manually activate the pipeline by calling `activate` (after a system turn), and the wakeword detector will apply its minimum/maximum activation lengths to control the duration of the activation.
     
     - SeeAlso: `wakeActiveMin`, `wakeActiveMax`
    */
    @objc public func activate() -> Void {
        self.wakewordRecognizerService.stopStreaming(context: self.context)
        self.speechRecognizerService.startStreaming(context: self.context)
    }
    
    /// Deactivates speech recognition.  The pipeline returns to awaiting either wakeword activation or an explicit `activate` call.
    /// - SeeAlso: `activate`
    @objc public func deactivate() -> Void {
        self.speechRecognizerService.stopStreaming(context: self.context)
        self.wakewordRecognizerService.startStreaming(context: self.context)
    }
    
    /// Starts  the speech pipeline.
    ///
    /// The pipeline starts in a deactivated state, awaiting either a wakeword activation or an explicit call to `activate`.
    @objc public func start() -> Void {
        if (self.context.isActive) {
            self.stop()
        }
        AudioController.sharedInstance.startStreaming(context: self.context)
        self.wakewordRecognizerService.startStreaming(context: self.context)
        self.pipelineDelegate?.didStart()
    }
    
    /// Stops the speech pipeline.
    ///
    /// All pipeline activity is stopped, and the pipeline cannot be activated until it is `start`ed again.
    @objc public func stop() -> Void {
        self.speechRecognizerService.stopStreaming(context: self.context)
        self.wakewordRecognizerService.stopStreaming(context: self.context)
        AudioController.sharedInstance.stopStreaming(context: self.context)
        self.pipelineDelegate?.didStop()
    }
}
