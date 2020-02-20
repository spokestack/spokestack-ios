//
//  NLUModelMetadata.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/29/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

internal struct NLUModelMeta {
    private let configuration: SpeechConfiguration
    internal let model: NLUModelMetadata
    
    init(_ configuration: SpeechConfiguration) throws {
        self.configuration = configuration

        let metadataURL = URL(fileURLWithPath: configuration.nluModelMetadataPath)
        let metaData = try Data(contentsOf: metadataURL)
        guard let metadata = try? JSONDecoder().decode(NLUModelMetadata.self, from: metaData) else {
            throw NLUError.metadata("Could not parse model metadata file set at nluModelMetadataPath.")
        }
        self.model = metadata
    }
}

internal struct NLUModelMetadata: Codable {
    let intents: [NLUModelIntent]
    let tags: Array<String>
}

internal struct NLUModelIntent: Codable {
    let name: String
    let slots: [NLUModelSlot]
}

internal struct NLUModelSlot: Codable {
    let name: String
    let type: String
    let facets: String
}

internal struct NLUModelSelset: Codable {
    let selections: [NLUModelSelsetSelection]
}

internal struct NLUModelSelsetSelection: Codable {
    let name: String
    let aliases: [String]
}

internal struct NLUModelInteger: Codable {
    let range: [Int]
}

internal struct NLUModelDigits: Codable {
    let count: Int
}
