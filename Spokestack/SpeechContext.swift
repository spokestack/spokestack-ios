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
    /// Current speech transcript
    @objc public var transcript: String = ""
    /// Current speech recognition confidence: [0-1)
    @objc public var confidence: Float = 0.0
    /// Speech recognition active indicator
    @objc public var isActive: Bool = false
    /// Speech detected indicator. Default to true for non-vad activation
    @objc public var isSpeech: Bool = true
    /// `SpeechProcessor` instances that process audio frames from `AudioController`.
    public var stageInstances: [SpeechProcessor] = []
    /// `SpeechEventListener`s that are sent `SpeechPipeline` events.
    public var listeners: [SpeechEventListener] = []
}
