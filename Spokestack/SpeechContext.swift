//
//  SpeechContext.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 10/1/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// This class maintains global state for the speech pipeline, allowing pipeline components to communicate information among themselves and event handlers.
@objc public class SpeechContext: NSObject {
    @objc public var configuration: SpeechConfiguration
    /// Current speech transcript
    @objc public var transcript: String = ""
    /// Current speech recognition confidence: [0-1)
    @objc public var confidence: Float = 0.0
    /// Speech recognition active indicator
    @objc public var isActive: Bool = false
    /// Speech detected indicator
    @objc public var isSpeech: Bool = false
    /// An ordered set of `SpeechEventListener`s that are sent `SpeechPipeline` events.
    private var listeners: [SpeechEventListener] = []
    /// Current error in the pipeline
    internal var error: Error?
    /// Current trace in the pipeline
    internal var trace: String?
    
    /// Initializes a speech context instance using the specified speech pipeline configuration.
    /// - Parameter config: The speech pipeline configuration used by the speech context instance.
    @objc public init(_ config: SpeechConfiguration) {
        self.configuration = config
    }
    
    /// Adds the specified listener instance to the ordered set of listeners. The specified listener instance may only be added once; duplicates will be ignored. The specified listener will recieve speech pipeline events.
    ///
    /// - Parameter listener: The listener to add.
    @objc internal func addListener(_ listener: SpeechEventListener) {
        if !self.listeners.contains(where: { l in
            return listener === l ? true : false
        }) {
            self.listeners.append(listener)
        }
    }
    
    /// Removes the specified listener by reference. The specified listener will no longer recieve speech pipeline events.
    /// - Parameter listener: The listener to remove.
    @objc internal func removeListener(_ listener: SpeechEventListener) {
        for (i, l) in self.listeners.enumerated() {
            _ = listener === l ? self.listeners.remove(at: i) : nil
        }
    }
    
    /// Removes all listeners.
    @objc internal func removeListeners() {
        self.listeners = []
    }

    @objc internal func dispatch(_ event: SpeechEvents) {
        self.listeners.forEach { listener in
            self.configuration.delegateDispatchQueue.async {
                switch event {
                case .initialize:
                    listener.didInit()
                case .start:
                    listener.didStart()
                case .stop:
                    listener.didStop()
                case .activate:
                    listener.didActivate()
                case .deactivate:
                    listener.didDeactivate()
                case .recognize:
                    listener.didRecognize(self)
                case .partiallyRecognize:
                    listener.didRecognizePartial?(self)
                case .error:
                    let e = (self.error != nil) ? self.error! : SpeechPipelineError.errorNotSet("A pipeline component attempted to send an error to SpeechContext's listeners without first setting the SpeechContext.error property.")
                    listener.failure(speechError: e)
                case .trace:
                    let t = (self.trace != nil) ? self.trace! : "a trace event was sent, but no trace message was set"
                        listener.didTrace(t)
                case .timeout:
                    listener.didTimeout()
                }
            }
        }
    }
}
