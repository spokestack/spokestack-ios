//
//  BertTokenizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/23/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// MARK: BasicTokenizer

/// A basic tokenizer where tokens are defined as alphanumeric words and punctuations.
internal struct BasicTokenizer: Tokenizer {
    
    /// Tokenizes the input text into an array of alphanumeric words and punctuations, discarding all other characters.
    /// - Parameter text: The text to tokenize.
    func tokenize(_ text: String) -> [String] {
        return text
            // normalize the string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en-US"))
            // prefix and suffix every punctuation character with a space (the space will be stripped out later) because there's no way to split on punctuation + whitespace/newlines in the same step.
            .map({ c in
                c.isPunctuation ? " \(c) " : String(c)
            })
            // convert the array of characters back to a string
            .joined()
            //  split the string into alphanumeric word/punctuation components. Also normalize the string again, removing all but alphanumerics and punctuation.
            .components(separatedBy: NSCharacterSet.alphanumerics.union(NSCharacterSet.punctuationCharacters).inverted)
            // remove spaces & newlines
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            // remove empty string
            .filter({ !$0.isEmpty })
    }
    
    /// Detokenizes the tokens into a space-separated string.
    /// - Parameter tokens: The tokens to transform into a String.
    func detokenize(_ tokens: [String]) throws -> String {
        return tokens.joined(separator: " ")
    }
}

/// MARK: WordpieceTokenizer

/// A tokenizer + encoder that tokenizes based on a supplied wordpiece vocabulary, and then encodes the wordpieces indexed to that vocabulary. Based on the Bert Wordpiece tokenizer.
internal struct WordpieceTokenizer: Tokenizer {
    private let encodings: [String: Int]
    private let piecePrefix = "##"
    private let unknownPiece = "[UNK]"
    
    /// Initializes an instance of the tokenizer with the provided vocabulary encodings.
    /// - Parameter encodings: A dictionary vocabulary of words : index to use for wordpiece tokenization/detokenization.
    init(_ encodings: [String: Int]) {
        self.encodings = encodings
    }
    
    /// Tokenize and encode the input text.
    /// - Parameter text: The input text to tokenize and encode.
    func tokenize(_ text: String) -> [String] {
        func piecewiseEncode(text: String, index: Int, pieces: [String], piecePrefix: String = "") -> [String] {
            if text.isEmpty {
                // base case: recursed through the text, so return the pieces collected
                return pieces
            }
            let prefix = piecePrefix + String(text.prefix(text.count - index))
            if encodings.keys.contains(prefix) {
                // recusive case: text is in dictionary, so add text to pieces and recurse on piece-tokenized suffix
                return piecewiseEncode(text: String(text.suffix(index)), index: 0, pieces: pieces + [prefix], piecePrefix: self.piecePrefix)
            } else if index == text.count {
                // recursive case: a part of the text is not in dictionary, so ignore pieces so far and return unknown
                return [self.unknownPiece]
            } else {
                // recursive case: text prefix not in dictionary, so keep piecewizing until text is found in dictionary
                return piecewiseEncode(text: text, index: index+1, pieces: pieces)
            }
        }
        
        if encodings.keys.contains(text) {
            return [text]
        } else {
            return piecewiseEncode(text: text, index: 1, pieces: [])
        }
    }
    
    /// Decode and detokenize the encoded tokens into a space-separated string.
    /// - Parameter tokens: The encoded tokens to decode and detokenize.
    func detokenize(_ tokens: [String]) throws -> String {
        return tokens.reduce("", { (result, s) in
            if result.count == 0 {
                return s
            } else if s.prefix(2) == self.piecePrefix {
                return result + s.suffix(s.count - 2)
            } else {
                return result + " " + s
            }
        })
    }
}

/// MARK: BertTokenizer

/// Using the `BasicTokenizer` and `WordpieceTokenizer`, performs tokenization + encoding/detokenization + decoding specific to the BERT NLU model.
internal class BertTokenizer {
    
    /// The maximum input token count the BERT model supports.
    internal var maxTokenLength: Int?
    
    private let minVocabLength = 2
    private var encodings: [String: Int] = [:]
    private var decodings: [Int: String] = [:]
    private let basicTokenizer = BasicTokenizer()
    private var wordpieceTokenizer: WordpieceTokenizer
    private var config: SpeechConfiguration
    
    /// Initializes a tokenizer using the provided configuration
    /// - Parameter config: Configuration parameters for the tokenizer.
    init(_ config: SpeechConfiguration) throws {
        self.config = config
        let vocab = try String(contentsOfFile: config.nluVocabularyPath)
        let tokens = vocab.split(separator: "\n").map { String($0) }
        for (id, token) in tokens.enumerated() {
            self.encodings[token] = id
            self.decodings[id] = token
        }
        self.wordpieceTokenizer = WordpieceTokenizer(self.encodings)
    }
    
    /// Tokenize the input text.
    /// - Parameter text: The input text to tokenize.
    func tokenize(_ text: String) -> [String] {
        return self.basicTokenizer.tokenize(text).flatMap({ self.wordpieceTokenizer.tokenize($0) })
    }
    
    /// Encode the tokens.
    /// - Parameter tokens: The tokens to encode.
    func encode(_ tokens: [String]) throws -> [Int] {
        guard let maxLength = self.maxTokenLength else {
            throw TokenizerError.invalidConfiguration("NLU model maximum input tokens length was not set.")
        }
        if tokens.count > maxLength {
            throw TokenizerError.tooLong("This model cannot encode (\(tokens.count) tokens. The maximum number it can encode is \(maxLength).")
        }
        if (self.encodings.underestimatedCount < minVocabLength) {
            throw TokenizerError.invalidConfiguration("Vocaubulary encodings not loaded. Please check SpeechConfiguration.nluEncodings.")
        }
        return tokens.map { (self.encodings[$0] ?? -1) } /// TODO: is -1 a good default here?
    }
    
    /// Tokenize and encode the input text.
    /// - Parameter text: The input text to tokenize and encode.
    func tokenizeAndEncode(_ text: String) throws -> [Int] {
        try self.encode(self.tokenize(text))
    }
    
    /// Decode the encoded tokens.
    /// - Parameter encoded: The encoded tokens to decode.
    func decode(_ encoded: [Int]) throws -> [String] {
        if (self.decodings.underestimatedCount < self.minVocabLength) {
            throw TokenizerError.invalidConfiguration("Vocaubulary encodings not loaded. Please check SpeechConfiguration.nluEncodings.")
        }
        return encoded.map { self.decodings[$0] ?? "[UNK]" } /// TODO: is [UNK] a good default here?
    }
    
    /// Detokenize the tokens.
    /// - Parameter tokens: The tokens to detokenize.
    func detokenize(_ tokens: [String]) throws -> String {
        return try basicTokenizer.detokenize(tokens)
    }
    
    /// Detokenize and decode the input text.
    /// - Parameter tokens: The encoded tokens to decode and detokenize.
    func decodeAndDetokenize(_ encoded: [Int]) throws -> String {
        try self.detokenize(self.decode(encoded))
    }
}
