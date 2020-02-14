//
//  Tokenizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/14/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// A simple protocol for Tokenizer services used by NLUService instances.
@objc public protocol Tokenizer {
    
    /// Tokenize the provided text into an array of tokens.
    /// - Parameter text: The text to tokenize.
    @objc func tokenize(text: String) -> [String]
    
    /// Detokenize the provided tokens into a string.
    /// - Parameter tokens: The tokens to detokenize.
    @objc func detokenize(tokens: [String]) throws -> String
}
