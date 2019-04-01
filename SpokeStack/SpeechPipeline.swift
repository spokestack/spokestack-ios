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
    
    public private (set) var speechService: RecognizerService?
    public private (set) var speechConfiguration: RecognizerConfiguration?
    public weak var speechDelegate: SpeechRecognizer?
    public private (set) var wakewordService: WakewordService?
    public private (set) var wakewordConfiguration: WakewordConfiguration?
    public weak var wakewordDelegate: WakewordRecognizer?
    public private (set) var pipelineDelegate: PipelineDelegate?
    public let context: SpeechContext = SpeechContext()
    
    
    // MARK: Private (properties)
    
    private var speechRecognizerService: SpeechRecognizerService
    private var wakewordRecognizerService: WakewordRecognizerService
    
    // MARK: Initializers
    
    deinit {
        print("Apple SpeechPipeline deinit")
        speechRecognizerService.delegate = nil
        wakewordRecognizerService.delegate = nil
    }
    
    @objc public init(_ speechService: RecognizerService,
                      speechConfiguration: RecognizerConfiguration,
                      speechDelegate: SpeechRecognizer?,
                      wakewordService: WakewordService,
                      wakewordConfiguration: WakewordConfiguration,
                      wakewordDelegate: WakewordRecognizer?,
                      pipelineDelegate: PipelineDelegate) throws {
        print("Apple SpeechPipeline init")
        self.speechService = speechService
        self.speechConfiguration = speechConfiguration
        self.speechDelegate = speechDelegate
        
        self.speechRecognizerService = speechService.speechRecognizerService
        self.speechRecognizerService.configuration = speechConfiguration
        self.speechRecognizerService.delegate = self.speechDelegate
        
        self.wakewordService = wakewordService
        self.wakewordConfiguration = wakewordConfiguration
        self.wakewordDelegate = wakewordDelegate
        
        self.wakewordRecognizerService = wakewordService.wakewordRecognizerService
        self.wakewordRecognizerService.configuration = wakewordConfiguration
        self.wakewordRecognizerService.delegate = self.wakewordDelegate
        
        self.pipelineDelegate = pipelineDelegate
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
    
    @objc public func setDelegates(_ speechDelegate: SpeechRecognizer?,
                                   wakewordDelegate: WakewordRecognizer?) -> Void {
        self.speechDelegate = speechDelegate
        self.wakewordDelegate = wakewordDelegate
        self.speechRecognizerService.delegate = self.speechDelegate
        self.wakewordRecognizerService.delegate = self.wakewordDelegate
    }
    
    @objc public func activate() -> Void {
        print("Apple SpeechPipeline activate")
        self.wakewordRecognizerService.stopStreaming(context: self.context)
        self.speechRecognizerService.startStreaming(context: self.context)
    }
    
    @objc public func deactivate() -> Void {
        print("Apple SpeechPipeline deactivate")
        self.speechRecognizerService.stopStreaming(context: self.context)
        self.wakewordRecognizerService.startStreaming(context: self.context)
    }
    
    @objc public func start() -> Void {
        print("Apple SpeechPipeline start, context isActive " + self.context.isActive.description)
        if (self.context.isActive) {
            self.stop()
        }
        AudioController.shared.startStreaming(context: self.context)
        self.wakewordRecognizerService.startStreaming(context: self.context)
        self.pipelineDelegate?.didStart()
    }
    
    @objc public func stop() -> Void {
        print("Apple SpeechPipeline stop")
        self.speechRecognizerService.stopStreaming(context: self.context)
        self.wakewordRecognizerService.stopStreaming(context: self.context)
        AudioController.shared.stopStreaming(context: self.context)
        self.pipelineDelegate?.didStop()
    }
}
