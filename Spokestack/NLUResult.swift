//
//  NLUResult.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/14/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// A simple data class that represents the result of an utterance classification.
@objc public class NLUResult: NSObject {
    
    /// The original utterance that was classified.
    @objc public var utterance: String
    
    /// The intent that the utterance was classified as.
    @objc public var intent: String
    
    /// Additional context included with the classification results.
    @objc public var context: [String : Any]
    
    /// The confidence level of the classification result.
    @objc public var confidence: Float
    
    /// The slot values present in the utterance.
    @objc public var slots: [String:Slot]
    
    /// The initializer for the NLU result.
    /// - Parameters:
    ///   - utterance: The original utterance that was classified.
    ///   - intent: The intent that the utterance was classified as.
    ///   - context: Additional context included with the classification results.
    ///   - confidence: The confidence level of the classification result.
    ///   - slots: The slot values present in the utterance.
    public init(utterance: String, intent: String, context: [String : Any] = [:], confidence: Float, slots: [String:Slot]) {
        self.utterance = utterance
        self.intent = intent
        self.context = context
        self.confidence = confidence
        self.slots = slots
    }
}

/// A slot extracted during intent classification.
/// - Remark: Depending on the NLU service used, slots may be typed; if present, the type of each slot can be accessed with the `type` property.
@objc public class Slot: NSObject {
    
    /// The underlying type of the slot value.
    @objc public var type: String
    
    /// The slot's value.
    @objc public var value: Any?
    
    /// The initializer for the NLU result slot.
    /// - Parameters:
    ///   - type: The underlying type of the slot value.
    ///   - value: The slot's value.
    public init(type: String, value: Any?) {
        self.type = type
        self.value = value
        super.init()
    }
}
