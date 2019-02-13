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
    
    public private (set) var speechService: RecognizerService
    public private (set) var speechConfiguration: RecognizerConfiguration
    public weak var speechDelegate: SpeechRecognizer?
    public private (set) var wakewordService: WakewordService
    public private (set) var wakewordConfiguration: WakewordConfiguration
    public weak var wakewordDelegate: WakewordRecognizer?
    public let context: SpeechContext = SpeechContext()

    
    // MARK: Private (properties)
    
    private var speechRecognizerService: SpeechRecognizerService
    private var wakewordRecognizerService: WakewordRecognizerService
    
    // MARK: Initializers
    
    deinit {
        speechRecognizerService.delegate = nil
        wakewordRecognizerService.delegate = nil
    }
    
    @objc public init(_ speechService: RecognizerService,
                speechConfiguration: RecognizerConfiguration,
                speechDelegate: SpeechRecognizer?,
                wakewordService: WakewordService,
                wakewordConfiguration: WakewordConfiguration,
                wakewordDelegate: WakewordRecognizer?) throws {

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
    }
    
    @objc public func activate() -> Void {
        self.speechRecognizerService.startStreaming(context: self.context)
    }
    
    @objc public func deactivate() -> Void {
        self.speechRecognizerService.stopStreaming(context: self.context)
    }
    
    @objc public func start() -> Void {
        self.wakewordRecognizerService.startStreaming(context: self.context)
    }
    
    @objc public func stop() -> Void {
        self.wakewordRecognizerService.stopStreaming(context: self.context)
    }
}
