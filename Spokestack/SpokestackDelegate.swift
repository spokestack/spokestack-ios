//
//  SpokestackDelegate.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 9/24/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc public protocol SpokestackDelegate: SpeechEventListener, TextToSpeechDelegate, NLUDelegate, Tracer {
    
    // MARK: SpeechEventListener
    
    /// The speech pipeline has been initialized.
    @objc optional func didInit() -> Void
    
    /// The speech pipeline has been started.
    @objc optional func didStart() -> Void
    
    /// The speech pipeline has been stopped.
    @objc optional func didStop() -> Void
    
    /// The pipeline activate event. Occurs upon activation of speech recognition.  The pipeline remains active until the user stops talking or the activation timeout is reached.
    /// - SeeAlso:  wakeActiveMin
    @objc optional func didActivate() -> Void
    
    /// The pipeline deactivate event. Occurs upon deactivation of speech recognition.  The pipeline remains inactive until activated again by either explicit activation or wakeword activation.
    @objc optional func didDeactivate() -> Void
    
    /// The pipeline recognized and transcribed speech.
    /// - Parameter result: The speech pipeline context, which contains the result.
    @objc optional func didRecognize(_ result: SpeechContext) -> Void
    
    /// The pipeline recognized and transcribed a portion of an incomplete utterance.
    /// - Parameter result: The speech pipeline context, which contains the partial result.
    @objc optional func didRecognizePartial(_ result: SpeechContext) -> Void
    
    /// The error event. An error occured in the speech pipeline.
    /// - Parameter error: A human-readable error message.
    @objc optional func failure(speechError: Error) -> Void
    
    /// The pipeline timeout event. The pipeline experienced a timeout in a component.
    @objc optional func didTimeout() -> Void
    
    // MARK: TextToSpeechDelegate
    
    /// The TTS synthesis request has resulted in a successful response.
    /// - Note: The URL will be invalidated within 60 seconds of generation.
    /// - Parameter url: The url pointing to the TTS media container
    @objc optional func success(result: TextToSpeechResult) -> Void
    
    /// The TTS synthesis request has resulted in an error response.
    /// - Parameter error: The error representing the TTS response.
    @objc optional func failure(ttsError: Error) -> Void
    
    /// The TTS synthesis request has begun playback over the default audio system.
    @objc optional func didBeginSpeaking() -> Void
    
    /// The TTS synthesis request has finished playback.
    @objc optional func didFinishSpeaking() -> Void
    
    // MARK: NLUDelegate
    
    /// The NLU classifier has produced a result.
    /// - Parameter result: The result of NLU classification.
    @objc optional func classification(result: NLUResult) -> Void
    
    /// The NLU classification request has resulted in an error response.
    /// - Parameter error: The error representing the NLU response.
    @objc optional func failure(nluError: Error) -> Void
    
    // MARK: Tracer
    
    /// The debug trace event.
    /// - Parameter trace: The debugging trace message.
    @objc optional func didTrace(_ trace: String) -> Void
}
