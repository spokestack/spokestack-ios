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
    
    /// Tokenize and encode the utterance into an `EncodedTokens` data structure
    /// - Parameter text: The input text to tokenize.
    func encode(text: String) throws -> EncodedTokens {
        // first create tokens out of whitespace
        let whitespacedTokens = text.components(separatedBy: .whitespacesAndNewlines)
        var normalizedTokens: [String] = []
        var indices: [Int] = []
        var encoded: [Int] = []
        // then componentize and wordpiece the whitespaced tokens, creating an even bigger set of normalized tokens
        for (id, wt) in whitespacedTokens.enumerated() {
            let tokens
                = self
                .componentize(wt)
                .flatMap({ self.wordpiece(text: $0) })
            normalizedTokens += tokens
            // finally encode the normalized tokens
            for t in tokens {
                encoded.append(self.encodings[t] ?? -1)
                indices.append(id)
            }
        }
        if encoded.count > self.config.nluMaxTokenLength {
            throw TokenizerError.tooLong("This input is represented by (\(encoded.count) tokens. The maximum number of tokens the model can classify is \(self.config.nluMaxTokenLength).")
        }
        return EncodedTokens(tokensByWhitespace: whitespacedTokens, encodedTokensByWhitespaceIndex: indicies, encodedTokens: encoded)
    }
    
    /// Decodes and reconstructs encoded tokens, inserting whitespace between each whitespace index.
    /// - Parameters:
    ///   - encodedTokens: The tokens to decode and join.
    ///   - whitespaceIndices: The desired indices from `encodedTokensByWhitespaceIndex`.
    func decodeWithWhitespace(encodedTokens: EncodedTokens, whitespaceIndices: [Int]) throws -> String {
        return try self.decode(encodedTokens: encodedTokens, whitespaceIndices: whitespaceIndices).joined(separator: " ")
    }
    
    /// Decodes and reconstructs encoded tokens.
    /// - Parameters:
    ///   - encodedTokens: The tokens to decode.
    ///   - whitespaceIndices: The desired indices from `encodedTokensByWhitespaceIndex`.
    func decode(encodedTokens: EncodedTokens, whitespaceIndices: [Int]) throws -> [String] {
        guard let tokensByWhitespace = encodedTokens.tokensByWhitespace else {
            throw NLUError.tokenizer("NLU model tokenizer did not encoded tokens for this range.")
        }
        // only unique numbers in the index will be reconstructed. This prevents duplications arising from wordpiece labeling.
        var uniques: Set<Int> = []
        return whitespaceIndicies
            // Filtering a set is O(1) vs O(n*2) reduce.
            .filter { uniques.insert($0).inserted }
            .map({ tokensByWhitespace[$0] })
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

/// A simple data structure for tokenization and encoding of an utterance, then reconstructing it.
internal struct EncodedTokens {
    /// An utterance, tokenized by whitespace.
    public var tokensByWhitespace: [String]?
    /// Each encoded token entry is represented by an index back to the whitespaced token.
    public var encodedTokensByWhitespaceIndex: [Int]?
    /// Whitespace-separated tokens, tokenized, wordpieced, and encoded for input into BERT.
    public var encodedTokens: [Int]?
}
