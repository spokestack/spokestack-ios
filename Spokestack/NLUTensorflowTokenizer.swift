//
//  NLUTensorflowTokenizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/23/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// A tokenizer + encoder that tokenizes based on a supplied wordpiece vocabulary, and then encodes the wordpieces indexed to that vocabulary. Based on the Bert Wordpiece tokenizer.
internal struct BertTokenizer {
    
    private var encodings: [String: Int] = [:]
    private var config: SpeechConfiguration
    private let piecePrefix = "##"
    private let unknownPiece = "[UNK]"
    
    /// Initializes a tokenizer using the provided configuration
    /// - Parameter config: Configuration parameters for the tokenizer.
    init(_ config: SpeechConfiguration) throws {
        self.config = config
        let vocab = try String(contentsOfFile: config.nluVocabularyPath)
        let tokens = vocab.split(separator: "\n").map { String($0) }
        for (id, token) in tokens.enumerated() {
            self.encodings[token] = id
        }
        if (self.encodings.underestimatedCount < 2) {
            throw TokenizerError.invalidConfiguration("NLU vocaubulary encodings not loaded. Please check SpeechConfiguration.nluEncodings.")
        }
    }
    
    /// Tokenize the input text.
    /// - Parameter text: The input text to tokenize.
    func tokenize(text: String) -> [String] {
        return self
            .componentize(text)
            .flatMap({ self.wordpiece(text: $0) })
    }
    
    /// Encode the tokens with the wordpiece encoder.
    /// - Parameter tokens: The tokens to encode.
    func encode(tokens: [String]) throws -> [Int] {
        if tokens.count > self.config.nluMaxTokenLength {
            throw TokenizerError.tooLong("This model cannot encode (\(tokens.count) tokens. The maximum number it can encode is \(self.config.nluMaxTokenLength).")
        }
        return tokens.map { (self.encodings[$0] ?? -1) } /// TODO: is -1 a good default here?
    }
    
    /// Decodes the encoded tokens.
    /// - Parameter tokens: The encoded tokens to decode.
    func decode(_ tokens: [String]) ->  [String] {
        return tokens
            .compactMap({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .reduce([], { (result, s) in
            if s.prefix(2) == self.piecePrefix {
                return result.dropLast() + [(result.last ?? "") + String(s.dropFirst(2))]
            } else {
                return result + [s]
            }
        })
    }

    /// Tokenizes the input text into an array of alphanumeric strings and punctuation, discarding all other characters.
    /// - Parameter text: The text to tokenize.
    private func componentize(_ text: String) -> [String] {
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
            // remove empty strings
            .filter({ !$0.isEmpty })
    }
    
    /// Tokenize  the input text with a wordpiece tokenizer.
    /// - Parameter text: The text to tokenize.
    private func wordpiece(text: String) -> [String] {
        func piecewiseTokenize(text: String, index: Int, pieces: [String], piecePrefix: String = "") -> [String] {
            if text.isEmpty {
                // base case: recursed through the text, so return the pieces collected
                return pieces
            }
            let prefix = piecePrefix + String(text.prefix(text.count - index))
            if encodings.keys.contains(prefix) {
                // recusive case: text is in dictionary, so add text to pieces and recurse on piece-tokenized suffix
                return piecewiseTokenize(text: String(text.suffix(index)), index: 0, pieces: pieces + [prefix], piecePrefix: self.piecePrefix)
            } else if index == text.count {
                // recursive case: a part of the text is not in dictionary, so ignore pieces so far and return unknown
                return [self.unknownPiece]
            } else {
                // recursive case: text prefix not in dictionary, so keep piecewizing until text is found in dictionary
                return piecewiseTokenize(text: text, index: index+1, pieces: pieces, piecePrefix: piecePrefix)
            }
        }
        
        if encodings.keys.contains(text) {
            return [text]
        } else {
            return piecewiseTokenize(text: text, index: 1, pieces: [])
        }
    }
}
