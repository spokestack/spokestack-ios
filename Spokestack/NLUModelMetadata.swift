//
//  NLUModelMetadata.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/29/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class Prediction: NSObject {
    @objc public var intent: String
    @objc public var confidence: Float
    @objc public var slots: [String:Slot]
    public init(intent: String, confidence: Float, slots: [String:Slot]) {
        self.intent = intent
        self.confidence = confidence
        self.slots = slots
    }
}

@objc public class Slot: NSObject {
    @objc public var type: String
    @objc public var value: Any?
    
    public init(type: String, value: Any) {
        self.type = type
        self.value = value
        super.init()
    }
}

internal struct NLUModelMeta {
    private let configuration: SpeechConfiguration
    internal let model: NLUModelMetadata
    
    init(_ configuration: SpeechConfiguration) throws {
        self.configuration = configuration

        let metadataURL = URL(fileURLWithPath: configuration.nluModelMetadataPath)
        let metaData = try Data(contentsOf: metadataURL)
        guard let metadata = try? JSONDecoder().decode(NLUModelMetadata.self, from: metaData) else {
        //try JSONSerialization.jsonObject(with: metaData, options: []) as? [String: Any] else {
            throw NLUError.metadata("Could not parse model metadata file set at nluModelMetadataPath.")
        }
        self.model = metadata
    }
}

internal struct NLUModelMetadata: Codable {
    let intents: [NLUModelIntent]
    let tags: NLUModelTags
}

internal struct NLUModelIntent: Codable {
    let name: String
    let slots: [NLUModelSlot]
}

internal struct NLUModelSlot: Codable {
    let name: String
    let type: String
    let selections: [NLUModelSelset]
}

internal struct NLUModelSelset: Codable {
    let name: String
    let aliases: [String]
}

typealias NLUModelTags = Array<String>
