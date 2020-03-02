//
//  NLUTensorflowMetadata.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/29/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Provides model-specific structured access to the NLU model metadata.
internal struct NLUTensorflowMeta {
    private let configuration: SpeechConfiguration
    internal let model: NLUTensorflowMetadata
    
    /// Using the provided configuration that includes the `nluModelMetadataPath`, hydrate the corresponding the metadata structure.
    /// - Parameter configuration: The global SpeechConfiguration.
    init(_ configuration: SpeechConfiguration) throws {
        self.configuration = configuration

        let metadataURL = URL(fileURLWithPath: configuration.nluModelMetadataPath)
        let metaData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(NLUTensorflowMetadata.self, from: metaData)
        self.model = metadata
    }
}

/// The internal nlu model metadata structure.
internal struct NLUTensorflowMetadata: Codable {
    let intents: [NLUTensorflowIntent]
    let tags: Array<String>
}

internal struct NLUTensorflowIntent: Codable {
    let name: String
    let slots: [NLUTensorflowSlot]
}

internal struct NLUTensorflowSlot: Codable {
    let name: String
    let type: String
    let facets: String
}

internal struct NLUTensorflowSelset: Codable {
    let selections: [NLUTensorflowSelsetSelection]
}

internal struct NLUTensorflowSelsetSelection: Codable {
    let name: String
    let aliases: [String]
}

internal struct NLUTensorflowInteger: Codable {
    let range: [Int]
}

internal struct NLUTensorflowDigits: Codable {
    let count: Int
}
