//
//  SpeechPipeline.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public final class SpeechPipeline {
    
    // MARK: Public (properties)
    
    public private (set) var service: RecognizerService
    
    public private (set) var configuration: RecognizerConfiguration
    
    public weak var delegate: SpeechRecognizer?
    
    // MARK: Private (properties)
    
    private var speechRecognizerService: SpeechRecognizerService = GoogleSpeechRecognizer.sharedInstance
    
    // MARK: Initializers
    
    deinit {
        speechRecognizerService.delegate = nil
    }
    
    public init(_ service: RecognizerService,
                configuration: RecognizerConfiguration,
                delegate: SpeechRecognizer?) throws {

        self.service = service
        self.configuration = configuration
        self.delegate = delegate
        
        self.speechRecognizerService.configuration = configuration
        self.speechRecognizerService = service.speechRecognizerService
        self.speechRecognizerService.delegate = self.delegate
    }
    
    public func start() -> Void {
        self.speechRecognizerService.startStreaming()
    }
    
    public func stop() -> Void {
        self.speechRecognizerService.stopStreaming()
    }
}
