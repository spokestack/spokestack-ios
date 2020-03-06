//
//  NLUTensorflowTokenizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/23/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// MARK: BasicTokenizer

/// A basic tokenizer where tokens are defined as alphanumeric strings and punctuation.
internal struct BasicTokenizer: Tokenizer {
    
    /// Tokenizes the input text into an array of alphanumeric strings and punctuation, discarding all other characters.
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
            //  split the string into alphanumeric (L* U N*) word/punctuation components. Also normalize the string again, removing all but alphanumerics and punctuation.
            .components(separatedBy: NSCharacterSet.alphanumerics.subtracting(NSCharacterSet.nonBaseCharacters).union(NSCharacterSet.punctuationCharacters).inverted)
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
                return piecewiseEncode(text: text, index: index+1, pieces: pieces, piecePrefix: piecePrefix)
            }
        }
        
        if encodings.keys.contains(text) {
            return [text]
        } else {
            return piecewiseEncode(text: text, index: 1, pieces: [])
        }
    }
    
    func decode(_ tokens: [String]) ->  [String] {
        return tokens
            .compactMap({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .reduce([], { (result, s) in
            if s.prefix(2) == self.piecePrefix {
                return result.dropLast() + [(result.last ?? "") + String(s.dropFirst(2))]
            } else if result.count > 0 {
                return result + [s]
            } else {
                return [s]
            }
        })
    }
    
    /// Decode and detokenize the encoded tokens into a space-separated string.
    /// - Parameter tokens: The encoded tokens to decode and detokenize.
    func detokenize(_ tokens: [String]) -> String {
        return self.decode(tokens).joined(separator: " ")
    }
}

/// MARK: BertTokenizer

/// Using the `BasicTokenizer` and `WordpieceTokenizer`, performs tokenization + encoding/detokenization + decoding specific to the BERT NLU model.
internal struct BertTokenizer {
    
    private var encodings: [String: Int] = [:]
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
        }
        self.wordpieceTokenizer = WordpieceTokenizer(self.encodings)
        if (self.encodings.underestimatedCount < 2) {
            throw TokenizerError.invalidConfiguration("NLU vocaubulary encodings not loaded. Please check SpeechConfiguration.nluEncodings.")
        }
    }
    
    /// Tokenize the input text.
    /// - Parameter text: The input text to tokenize.
    func tokenize(_ text: String) -> [String] {
        return self.basicTokenizer.tokenize(text).flatMap({ self.wordpieceTokenizer.tokenize($0) })
    }
    
    /// Encode the tokens.
    /// - Parameter tokens: The tokens to encode.
    func encode(_ tokens: [String]) throws -> [Int] {
        if tokens.count > self.config.nluMaxTokenLength {
            throw TokenizerError.tooLong("This model cannot encode (\(tokens.count) tokens. The maximum number it can encode is \(self.config.nluMaxTokenLength).")
        }
        return tokens.map { (self.encodings[$0] ?? -1) } /// TODO: is -1 a good default here?
    }
        
    /// Tokenize and encode the input text.
    /// - Parameter text: The input text to tokenize and encode.
    func tokenizeAndEncode(_ text: String) throws -> [Int] {
        try self.encode(self.tokenize(text))
    }
    
    func decode(_ tokens: [String]) ->  [String] {
        return wordpieceTokenizer.decode(tokens)
    }
    
    /// Detokenize the tokens.
    /// - Parameter tokens: The tokens to detokenize.
    func detokenize(_ tokens: [String]) -> String {
        return wordpieceTokenizer.detokenize(tokens)
    }
}
