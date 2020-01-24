//
//  Tokenizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/23/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

public class Tokenizer {
    private let maxTokenLength = 128
    private let minVocabLength = 2
    private var encodings: [String: Int] = [:]
    private var decodings: [Int: String] = [:]
    private var config: SpeechConfiguration
    
    public init(_ config: SpeechConfiguration) {
        self.config = config
        let vocab = try? String(contentsOfFile: config.vocabularyPath)
        let tokens = vocab?.split(separator: "\n").map { String($0) }
        guard let tkns = tokens else {
            return
        }
        for (id, token) in tkns.enumerated() {
            self.encodings[token] = id
            self.decodings[id] = token
        }
    }
    
    public func tokenize(_ text: String) -> [String] {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en-US"))
            .components(separatedBy: NSCharacterSet.alphanumerics.inverted)
            .filter({$0 != ""})
    }
    
    /// let encodedText = encode(tokenize(text))
    public func encode(_ tokens: [String]) throws -> [Int] {
        if tokens.count > self.maxTokenLength {
            throw TokenizerError.tooLong("This model cannot encode (\(tokens.count) tokens. The maximum number it can encode is \(self.maxTokenLength).")
        }
        if (self.encodings.underestimatedCount < minVocabLength) {
            throw TokenizerError.invalidConfiguration("Vocaubulary encodings not loaded. Please check SpeechConfiguration.nluEncodings.")
        }
        return tokens.map { (self.encodings[$0] ?? -1) }
    }
    
    public func tokenizeAndEncode(_ text: String) throws -> [Int] {
        try self.encode(self.tokenize(text))
    }
    
    public func decode(_ encoded: [Int]) throws -> [String] {
        if (self.decodings.underestimatedCount < self.minVocabLength) {
            throw TokenizerError.invalidConfiguration("Vocaubulary encodings not loaded. Please check SpeechConfiguration.nluEncodings.")
        }
        return encoded.map { self.decodings[$0] ?? "unknown" }
    }
    
    /// let text = detokenize(decode(encodedText))
    public func detokenize(_ tokens: [String]) throws -> String {
        return tokens.joined(separator: " ")
    }
    
    public func decodeAndDetokenize(_ encoded: [Int]) throws -> String {
        try self.detokenize(self.decode(encoded))
    }
}
