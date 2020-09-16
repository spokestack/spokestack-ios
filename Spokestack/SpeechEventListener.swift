//
//  SpeechEventListener.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Functions required for components to receive speech pipeline control events.
///
/// Interpretation of how to respond to these control events is the responsibility of the component.
@objc public protocol SpeechEventListener: AnyObject {
    
    /// The speech pipeline has been initialized.
    @objc func didInit() -> Void
    
    /// The speech pipeline has been started.
    @objc func didStart() -> Void
    
    /// The speech pipeline has been stopped.
    @objc func didStop() -> Void
    
    /// The pipeline activate event. Occurs upon activation of speech recognition.  The pipeline remains active until the user stops talking or the activation timeout is reached.
    /// - SeeAlso:  wakeActiveMin
    @objc func didActivate() -> Void
    
    /// The pipeline deactivate event. Occurs upon deactivation of speech recognition.  The pipeline remains inactive until activated again by either explicit activation or wakeword activation.
    @objc func didDeactivate() -> Void
    
    /// The pipeline recognized and transcribed speech.
    /// - Parameter result: The speech pipeline context, which contains the result.
    @objc func didRecognize(_ result: SpeechContext) -> Void
    
    /// The pipeline recognized and transcribed a portion of an incomplete utterance.
    /// - Parameter result: The speech pipeline context, which contains the partial result.
    @objc optional func didRecognizePartial(_ result: SpeechContext) -> Void
    
    /// The error event. An error occured in the speech pipeline.
    /// - Parameter error: A human-readable error message.
    @objc func failure(speechError: Error) -> Void
    
    /// The debug trace event.
    /// - Parameter trace: The debugging trace message.
    @objc func didTrace(_ trace: String) -> Void
    
    /// The pipeline timeout event. The pipeline experienced a timeout in a component.
    @objc func didTimeout() -> Void
}
