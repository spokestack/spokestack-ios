//
//  SpeechEventListener.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Functions required for components to receive speech pipeline control events.
///
/// Interpretation of how to respond to these control events is the responsibility of the component.
@objc public protocol SpeechEventListener: AnyObject {
    
    /// The pipeline activate event. Occurs upon activation of speech recognition.  The pipeline remains active until the user stops talking or the activation timeout is reached.
    /// - SeeAlso:  wakeActiveMin
    func activate() -> Void
    
    /// The pipeline deactivate event. Occurs upon deactivation of speech recognition.  The pipeline remains inactive until activated again by either explicit activation or wakeword activation.
    func deactivate() -> Void
    
    /// The error event. An error occured in the speech pipeline.
    /// - Parameter error: A human-readable error message.
    func didError(_ error: Error) -> Void
    
    /// The debug trace event.
    /// - Parameter trace: The debugging trace message.
    func didTrace(_ trace: String) -> Void
    
    /// The pipeline speech recognition result event. The pipeline was activated and recognized speech.
    /// - Parameter result: The speech recognition result.
    func didRecognize(_ result: SpeechContext) -> Void
    
    /// The pipeline timeout event. The pipeline experienced a timeout in a component.
    func didTimeout() -> Void
}
