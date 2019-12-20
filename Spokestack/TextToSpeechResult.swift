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
    @objc public var url: URL = URL(string: "https://spokestack.io")!
    @objc public var id: String = ""
}
