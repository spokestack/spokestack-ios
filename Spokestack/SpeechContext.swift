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
    public var configuration: SpeechConfiguration
    /// Current speech transcript
    @objc public var transcript: String = ""
    /// Current speech recognition confidence: [0-1)
    @objc public var confidence: Float = 0.0
    /// Speech recognition active indicator
    @objc public var isActive: Bool = false
    /// Speech detected indicator. Default to true for non-vad activation
    @objc public var isSpeech: Bool = true
    /// A set of `SpeechProcessor` instances that process audio frames from `AudioController`.
    public var stageInstances: [SpeechProcessor] = []
    /// A set of `SpeechEventListener`s that are sent `SpeechPipeline` events.
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
    
    /// Adds the specified listener instance to the ordered set of listeners. The specified listener will recieve speech pipeline events.
    ///
    /// - Parameter listener: The listener to add.
    @objc public func setListener(_ listener: SpeechEventListener) {
        if self.listeners.contains(where: { l in
            return listener === l ? true : false
        }) { } else {
            self.listeners.append(listener)
        }
    }
    
    /// Removes the specified listener by reference. The specified listener will no longer recieve speech pipeline events.
    /// - Parameter listener: The listener to remove.
    @objc public func removeListener(_ listener: SpeechEventListener) {
        for (i, l) in self.listeners.enumerated() {
            _ = listener === l ? self.listeners.remove(at: i) : nil
        }
    }
    
    /// Removes all listeners.
    @objc public func removeListeners() {
        self.listeners = []
    }

    @objc public func setStage(_ stage: SpeechProcessor) {
        
    }

    @objc public func removeStage(_ stage: SpeechProcessor) {
        
    }

    @objc internal func notifyListener(_ about: SpeechEvents) {
        self.listeners.forEach { listener in
            self.configuration.delegateDispatchQueue.async {
                switch about {
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
                case .error:
                    guard let e = self.error else {
                        listener.failure(speechError: SpeechPipelineError.errorNotSet("A pipeline component attempted to send an error to SpeechContext's listeners without first setting the SpeechContext.error property."))
                        return
                    }
                    listener.failure(speechError: e)
                    self.error = .none
                case .trace:
                    guard let t = self.trace else {
                        // swallow this error case because traces aren't important to the client.
                        return
                    }
                    listener.didTrace(t)
                    self.trace = .none
                case .timeout:
                    listener.didTimeout()
                }
            }
        }
    }
}
