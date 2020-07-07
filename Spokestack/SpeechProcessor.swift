//
//  SpeechProcessor.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Protocol for speech pipeline components to receive speech pipeline coordination events.
///
/// `startStreaming` and `stopStreaming` are expected to be called repeatedly while the pipeline is running, and should respond to these functions by allocating and deallocating resources in order to optimize performance.
@objc public protocol SpeechProcessor: AnyObject {
    
    /// The global configuration for all speech pipeline components.
    var configuration: SpeechConfiguration { get set }
    
    /// Global speech context.
    var context: SpeechContext { get set }
    
    /// Trigger from the speech pipeline for the component to begin processing the audio stream.
    /// - Parameter context: The current speech context.
    func startStreaming(context: SpeechContext) -> Void
    
    /// Trigger from the speech pipeline for the component to stop processing the audio stream.
    /// - Parameter context: The current speech context.
    func stopStreaming(context: SpeechContext) -> Void
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    /// - Parameter frame: Audio frame of samples.
    func process(_ frame: Data) -> Void
}

/// Convenience enum for the singletons of the different implementers of the `SpeechProcessor` protocol.
@objc public enum SpeechProcessors: Int {
    /// AppleWakewordRecognizer
    case appleWakeword
    /// TFLiteWakewordRecognizer
    case tfLiteWakeword
    /// AppleSpeechRecognizer
    case appleSpeech
    /// WebRTCVAD
    case vad
}
