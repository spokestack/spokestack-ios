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
    /// An ordered set of `SpokestackDelegate`s that are sent events from Spokestack subsystems.
    private var listeners: [SpokestackDelegate] = []
    
    /// Initializes a speech context instance using the specified speech pipeline configuration.
    /// - Parameter config: The speech pipeline configuration used by the speech context instance.
    @objc public init(_ config: SpeechConfiguration) {
        self.configuration = config
    }
    
    /// Adds the specified listener instance to the ordered set of listeners. The specified listener instance may only be added once; duplicates will be ignored. The specified listener will recieve speech pipeline events.
    ///
    /// - Parameter listener: The listener to add.
    internal func addListener(_ listener: SpokestackDelegate) {
        if !self.listeners.contains(where: { l in
            return listener === l ? true : false
        }) {
            self.listeners.append(listener)
        }
    }
    
    /// Removes the specified listener by reference. The specified listener will no longer recieve speech pipeline events.
    /// - Parameter listener: The listener to remove.
    internal func removeListener(_ listener: SpokestackDelegate) {
        for (i, l) in self.listeners.enumerated() {
            _ = listener === l ? self.listeners.remove(at: i) : nil
        }
    }
    
    /// Removes all listeners.
    @objc internal func removeListeners() {
        self.listeners = []
    }
    
    internal func dispatch(_ handler: @escaping (SpokestackDelegate) -> Void) {
        self.configuration.delegateDispatchQueue.async {
            self.listeners.forEach(handler)
        }
    }
}
