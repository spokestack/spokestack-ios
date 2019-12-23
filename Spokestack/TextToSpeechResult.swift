//
//  TextToSpeechResult.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 12/20/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Result of the `TextToSpeech.synthesize` request.
public class TextToSpeechResult: NSObject {
    public var url: URL?
    public var id: String?
    
    public init (id: String, url: URL) {
        self.id = id
        self.url = url
    }
}
