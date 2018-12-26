//
//  SpeechPipeline.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public enum SpeechPipelineError: Error {
    case illegalState(message: String)
}

public final class SpeechPipeline {
    
    // MARK: Public (properties)
    
    public private (set) var service: RecognizerService
    
    public private (set) var configuration: RecognizerConfiguration
    
    public private (set) var wakeWordConfig: WakeRecognizerConfiguration? {
        
        didSet {
            
            if let currentWakeWordConfig: WakeRecognizerConfiguration = wakeWordConfig {
                self.wakeWordController = WakeWordController(currentWakeWordConfig)
            }
        }
    }
    
    public weak var delegate: SpeechRecognizer?
    
    // MARK: Private (properties)
    
    private var speechRecognizerService: SpeechRecognizerService = GoogleSpeechRecognizer.sharedInstance
    
    private var wakeWordController: WakeWordController!
    
    // MARK: Initializers
    
    deinit {
        speechRecognizerService.delegate = nil
    }
    
    public init(_ service: RecognizerService,
                configuration: RecognizerConfiguration,
                delegate: SpeechRecognizer?,
                wakeWordConfig: WakeRecognizerConfiguration?) throws {
        
        func didInitialize() -> Bool {
            
            var didInitialize: Bool = false
            
            switch service {
            case .google where configuration is GoogleRecognizerConfiguration:

                self.speechRecognizerService.configuration = configuration
                
                didInitialize = true
                break
            default: break
            }
            
            return didInitialize
        }
        
        self.speechRecognizerService = service.speechRecognizerService
        self.speechRecognizerService.delegate = self.delegate
        
        self.service = service
        self.configuration = configuration
        self.delegate = delegate
        self.wakeWordConfig = wakeWordConfig
        self.wakeWordController = WakeWordController(wakeWordConfig!)
        
        if !didInitialize() {

            let errorMessage: String = """
            The service must be google and your configuration must conform to GoogleRecognizerConfiguration.
            Future release will support other services.
            """
            throw SpeechPipleError.invalidInitialzation(errorMessage)
        }
    }
    
    public func start() -> Void {
        
        guard let _: WakeRecognizerConfiguration = self.wakeWordConfig else {
            
            self.speechRecognizerService.startStreaming()
            return
        }
        
        self.wakeWordController.activate()
    }
    
    public func stop() -> Void {
        
        guard let _: WakeRecognizerConfiguration = self.wakeWordConfig else {
            
            self.speechRecognizerService.stopStreaming()
            return
        }
        
        self.wakeWordController.deactivate()
    }
}
