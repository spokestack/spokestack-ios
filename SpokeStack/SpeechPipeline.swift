//
//  SpeechPipeline.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public final class SpeechPipeline: NSObject {
    
    // MARK: Public (properties)
    
    public private (set) var speechService: SpeechProcessors?
    public private (set) var speechConfiguration: SpeechConfiguration?
    public weak var speechDelegate: SpeechEventListener?
    public private (set) var wakewordService: SpeechProcessors?
    public weak var wakewordDelegate: SpeechEventListener?
    public private (set) var pipelineDelegate: PipelineDelegate?
    public let context: SpeechContext = SpeechContext()
    
    
    // MARK: Private (properties)
    
    private var speechRecognizerService: SpeechProcessor
    private var wakewordRecognizerService: SpeechProcessor
    
    // MARK: Initializers
    
    deinit {
        speechRecognizerService.delegate = nil
        wakewordRecognizerService.delegate = nil
    }
    
    @objc public init(_ speechService: SpeechProcessors,
                      speechConfiguration: SpeechConfiguration,
                      speechDelegate: SpeechEventListener,
                      wakewordService: SpeechProcessors,
                      wakewordDelegate: SpeechEventListener,
                      pipelineDelegate: PipelineDelegate) throws {
        self.speechService = speechService
        self.speechConfiguration = speechConfiguration
        self.speechDelegate = speechDelegate
        
        self.speechRecognizerService = speechService.speechProcessor
        /// order is important: set the delegate first so that configuration errors/tracing can be sent back
        self.speechRecognizerService.delegate = self.speechDelegate
        self.speechRecognizerService.configuration = speechConfiguration
        
        self.wakewordService = wakewordService
        self.wakewordDelegate = wakewordDelegate
        
        self.wakewordRecognizerService = wakewordService.speechProcessor
        /// see previous comment
        self.wakewordRecognizerService.delegate = self.wakewordDelegate
        self.wakewordRecognizerService.configuration = speechConfiguration
        
        AudioController.sharedInstance.configuration = speechConfiguration
        
        self.pipelineDelegate = pipelineDelegate
        AudioController.sharedInstance.pipelineDelegate = self.pipelineDelegate
        self.pipelineDelegate!.didInit()
    }
    
    @objc public func status() -> Bool {
        guard
            let _ = self.speechDelegate,
            let _ = self.wakewordDelegate,
            let _ = self.pipelineDelegate
        else {
            return true
        }
        return false
    }
    
    @objc public func setDelegates(_ speechDelegate: SpeechEventListener,
                                   wakewordDelegate: SpeechEventListener) -> Void {
        self.speechDelegate = speechDelegate
        self.wakewordDelegate = wakewordDelegate
        self.speechRecognizerService.delegate = self.speechDelegate
        self.wakewordRecognizerService.delegate = self.wakewordDelegate
    }
    
    @objc public func activate() -> Void {
        self.wakewordRecognizerService.stopStreaming(context: self.context)
        self.speechRecognizerService.startStreaming(context: self.context)
    }
    
    @objc public func deactivate() -> Void {
        self.speechRecognizerService.stopStreaming(context: self.context)
        self.wakewordRecognizerService.startStreaming(context: self.context)
    }
    
    @objc public func start() -> Void {
        if (self.context.isActive) {
            self.stop()
        }
        AudioController.sharedInstance.startStreaming(context: self.context)
        self.wakewordRecognizerService.startStreaming(context: self.context)
        self.pipelineDelegate?.didStart()
    }
    
    @objc public func stop() -> Void {
        self.speechRecognizerService.stopStreaming(context: self.context)
        self.wakewordRecognizerService.stopStreaming(context: self.context)
        AudioController.sharedInstance.stopStreaming(context: self.context)
        self.pipelineDelegate?.didStop()
    }
}
