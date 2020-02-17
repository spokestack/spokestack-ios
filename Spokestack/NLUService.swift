//
//  NLUService.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/14/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// A simple protocol for NLU services that provide intent classification and slot recognition, either on-device or via a network request.
@objc public protocol NLUService {
    
    /// The global configuration for all speech pipeline components.
    @objc var configuration: SpeechConfiguration {get set}
    
    /// Delegate that receives NLU service events.
    @objc var delegate: NLUDelegate? {get set}
    
    /// The initializer for the NLU service.
    /// - Parameters:
    ///   - delegate: Delegate that receives NLU service events.
    ///   - configuration: The global configuration for all speech pipeline components.
    @objc init(_ delegate: NLUDelegate, configuration: SpeechConfiguration) throws
    
    /// Classifies a user utterance into an intent, sending the result to the NLUDelegate.
    /// - Parameters:
    ///   - utterance: The user utterance to be classified.
    ///   - context: Any contextual information that should be sent along with the utterance to assist classification.
    @objc func classify(utterance: String, context: [String : Any]) -> Void
}
