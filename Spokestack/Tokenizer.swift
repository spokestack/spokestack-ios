//
//  Tokenizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/13/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

public protocol Tokenizer {
    func tokenize(_ text: String) -> [String]
    func detokenize(_ tokens: [String]) throws -> String
}
