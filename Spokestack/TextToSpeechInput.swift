//
//  TextToSpeechInput.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 11/19/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Input parameters for speech synthesis. Parameters are considered transient and may change each time `synthesize` is called.
/// - SeeAlso: `TextToSpeech.synthesize`
@objc public class TextToSpeechInput: NSObject {
    
    /// Initializer for a new TextToSpeechInput instance.
    @objc public override init() {
        super.init()
    }
    
    /// Convenience initializer for a new TextToSpeechInput instance.
    /// - Parameter input: The text input to the speech synthesizer.
    @objc public init(_ input: String) {
        self.input = input
        super.init()
    }

    /// Convenience initializer for a new TextToSpeechInput instance.
    /// - Parameter input: The text input to the speech synthesizer.
    /// - Parameter voice: The synthetic voice used to generate speech.
    /// - Parameter inputFormat: The formatting of the input.
    @objc public init(_ input:String, inputFormat: TTSInputFormat) {
        self.input = input
        self.inputFormat = inputFormat
    }
    
    /// Convenience initializer for a new TextToSpeechInput instance.
    /// - Parameter input: The text input to the speech synthesizer.
    /// - Parameter voice: The synthetic voice used to generate speech.
    /// - Parameter inputFormat: The formatting of the input.
    @objc public init(_ input:String, voice: String, inputFormat: TTSInputFormat) {
        self.input = input
        self.voice = voice
        self.inputFormat = inputFormat
    }
    
    /// The synthetic voice used to generate speech.
    @objc public var voice: String = "demo-male"
    /// The input to the synthetic voice.
    /// - Note: SSML should be unescaped.
    @objc public var input: String = "Here I am, a brain the size of a planet."
    /// The formatting of the input.
    @objc public var inputFormat: TTSInputFormat = .text
}
