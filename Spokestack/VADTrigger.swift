//
//  VADTrigger.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/7/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc public class VADTrigger: NSObject, SpeechProcessor {
    /// Configuration for the trigger.
    public var configuration: SpeechConfiguration
    
    /// Global state for the speech pipeline.
    public var context: SpeechContext
    
    /// Initializes an instance of VADTrigger.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    public func startStreaming() {}
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    public func stopStreaming() {}
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    /// - Parameter frame: Frame of audio samples.
    public func process(_ frame: Data) {
        if self.context.isSpeech && !self.context.isActive {
            self.context.isActive = true
            self.configuration.delegateDispatchQueue.async {
                self.context.listeners.forEach { listener in
                    listener.didActivate()
                }
            }
        } else if !self.context.isSpeech && self.context.isActive {
//            self.context.isActive = false
        }
    }
}
