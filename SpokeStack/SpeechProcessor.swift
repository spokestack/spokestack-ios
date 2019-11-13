//
//  SpeechProcessor.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Protocol for speech pipeline components to receive speech pipeline coordination events.
///
/// `startStreaming` and `stopStreaming` are expected to be called repeatedly while the pipeline is running, and should respond to these functions by allocating and deallocating resources in order to optimize performance.
@objc public protocol SpeechProcessor: AnyObject {
    
    /// The global configuration for all speech pipeline components.
    var configuration: SpeechConfiguration? { get set }
    
    /// Delegate for sending speech pipeline control events.
    ///
    /// The interpretation of what control event to trigger based on a component processing result is left to the component.
    var delegate: SpeechEventListener? { get set }
    
    /// Global speech context.
    var context: SpeechContext { get set }
    
    /// Trigger from the speech pipeline for the component to begin processing the audio stream.
    /// - Parameter context: The current speech context.
    func startStreaming(context: SpeechContext) -> Void
    
    /// Trigger from the speech pipeline for the component to stop processing the audio stream.
    /// - Parameter context: The current speech context.
    func stopStreaming(context: SpeechContext) -> Void
}
