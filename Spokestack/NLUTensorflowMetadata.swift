//
//  NLUTensorflowMetadata.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/29/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Provides model-specific structured access to the NLU model metadata.
/// - TODO: implement an extensible slot parsing model a la https://medium.com/makingtuenti/indeterminate-types-with-codable-in-swift-5a1af0aa9f3d or https://www.swiftbysundell.com/articles/customizing-codable-types-in-swift/
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
    let facets: String?
    
    /// Returns the internal structure represented by the facet
    /// - TODO: This should use some sort of caching strategy to avoid repeated runtime decodings since the metadata is static.
    func parsed() throws -> Any? {
        guard let facetData = self.facets?.data(using: .utf16) else {
            throw NLUError.metadata("The NLU metadata for \(self.name) could not be parsed and may be malformed.")
        }
        switch self.type {
            case "selset":
                return try JSONDecoder().decode(NLUTensorflowSelset.self, from: facetData)
            case "integer":
               return try JSONDecoder().decode(NLUTensorflowInteger.self, from: facetData)
            case "digits":
                return try JSONDecoder().decode(NLUTensorflowDigits.self, from: facetData)
        default:
            throw NLUError.metadata("The NLU metadata for \(self.name)'s type is not defined.")
        }
    }
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
