//
//  TextToSpeechResult.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 12/20/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Result of the `TextToSpeech.synthesize` request.
@objc public class TextToSpeechResult: NSObject {
    @objc public var url: URL?
    @objc public var id: String?
    
    @objc public init (id: String, url: URL) {
        self.id = id
        self.url = url
        super.init()
    }
}
