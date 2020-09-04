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
    @objc public var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    @objc public var context: SpeechContext

    /// Initializes a VADTrigger instance.
    ///
    /// A wakeword trigger is initialized by, and receives `startStreaming` and `stopStreaming` events from, an instance of `SpeechPipeline`.
    ///
    /// The VADTrigger receives audio data frames to `process` from `AudioController`.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
    }

    /// Triggered by the speech pipeline, instructing the trigger to begin streaming and processing audio.
    @objc public func startStreaming() {}

    /// Triggered by the speech pipeline, instructing the trigger to stop streaming audio and complete processing.
    @objc public func stopStreaming() {}

    /// Processes an audio frame, activating the pipeline if speech is detected.
    /// - Parameter frame: Audio frame of samples.
    @objc public func process(_ frame: Data) {
        if self.context.isSpeech && !self.context.isActive {
            self.context.isActive = true
            self.context.dispatch(.activate)
        }
    }
    
    
}
