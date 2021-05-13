//
//  CommandModelMetadata.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 5/11/21.
//  Copyright © 2021 Spokestack, Inc. All rights reserved.
//

import Foundation

internal struct CommandModelMeta {
    private let configuration: SpeechConfiguration
    internal let model: CommandModelMetadata
    
    init(_ configuration: SpeechConfiguration) throws {
        self.configuration = configuration
        let metadataURL = URL(fileURLWithPath: configuration.keywordMetadataPath)
        let metaData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(CommandModelMetadata.self, from: metaData)
        self.model = metadata
    }
}

internal struct CommandModelMetadata: Codable {
    let classes: [CommandModelMetadataUtterances]
    let name: String
    let type: String
    let revision: String?
}

internal struct CommandModelMetadataUtterances: Codable {
    let name: String
    let utterances: [CommandModelMetadataUtterance]
}

internal struct CommandModelMetadataUtterance: Codable {
    let id: String
    let text: String
}
