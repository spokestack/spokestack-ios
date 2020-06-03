//
//  NLUTensorflowSlotParsers.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/25/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Provides a parser for reconstructing nlu slot values from the input and IOB tag labels.
internal struct NLUTensorflowSlotParser {
    
    /// Parse the classification output and predicted tag labels into a structured `[intent : Slot]` dictionary.
    /// - Note: This operation effectively truncates the tag labels by the input size, ignoring all labels outside the input token count.
    /// - Parameters:
    ///   - tags: An array of classification tag labels.
    ///   - intent: The predicted intent.
    ///   - encoder: The tokenizer instance to decode the `encodedTokens`.
    ///   - encodedTokens: The tokens and associated metadata to decode for slot values.
    /// - Throws: NLUError if the model output indicates a slot value that is not parseable.
    /// - Returns: A structured `[intent : Slot]` dictionary of intent name keys with the slots defined by the intent and the slot's values as determined by the model output.
    internal func parse(tags: [String], intent: NLUTensorflowIntent, encoder: BertTokenizer, encodedTokens: EncodedTokens) throws -> [String:Slot]? {
        // zip together the tags (ignoring the "o" tag) and the index of the whitespaced encoded tokens, then process into the return type
        let tagsToTokens = zipTagsAndTokens(tags: tags, encodedTokens: encodedTokens)
        // intents define a fixed set of slots, so for each slot in the intent, determine if the model has produced a value for it.
        return try intentSlotMap(intent: intent, tagsToTokens: tagsToTokens, encoder: encoder, encodedTokens: encodedTokens)
    }
    
    /// Zip together the tags (ignoring the "o" tag) and the index of the whitespaced encoded tokens.
    /// - Parameters:
    ///   - tags: An array of classification tag labels.
    ///   - encodedTokens: The tokens and associated metadata to decode for slot values.
    /// - Returns: A dictionary of slot name keys with input token values.
    private func zipTagsAndTokens(tags: [String], encodedTokens: EncodedTokens) -> [String : [Int]] {
        // The model output is fixed-length ordered tags, which can be zipped with the fixed-length ordered input tokens
        zip(tags, 0...encodedTokens.encodedTokensByWhitespaceIndex.count)
            // create a dictionary of [tags: [tokenIndices]]
            .reduce(into: [:] as [String: [Int]], { result, tagIndex in
                // the model slot classifier uses IOB tags. Ignore the "o" tag.
                let (tag, index) = tagIndex
                if  tag != "o" {
                    // Strip off `b_` and `i_` prefixes to resolve tag labels to slot names.
                    let slotToken = [String(tag.dropFirst(2)): [encodedTokens.encodedTokensByWhitespaceIndex[index]]]
                    // collect all the tokens with the same slot type into a single array
                    result.merge(slotToken, uniquingKeysWith: { $0 + $1 })
                }
            })
    }
    
    /// Return a fixed set of slots defined by the intent, with values determined by the zip of model output tags to input tokens.
    /// - Parameters:
    ///   - intent:  The predicted intent.
    ///   - tagsToTokens: Zip of tags (ignoring the "o" tag) and the index of the whitespaced encoded tokens.
    ///   - encoder: The tokenizer instance to decode the `encodedTokens`.
    ///   - encodedTokens: The tokens and associated metadata to decode for slot values.
    /// - Throws: NLUError if the model output indicates a slot value that is not parseable.
    /// - Returns: A structured `[intent : Slot]` dictionary of intent name keys with the slots defined by the intent and the slot's values as determined by the model output.
    private func intentSlotMap(intent: NLUTensorflowIntent, tagsToTokens: [String : [Int]], encoder: BertTokenizer, encodedTokens: EncodedTokens) throws -> [String:Slot]? {
        var slots: [String:Slot] = [:]
        // Iterate over the slots defined by the intent, checking if each one has a value in the model output.
        for slot in intent.slots {
            if let tokenIndices = tagsToTokens[slot.name] {
                // decode and parse tokenIndices
                let parsed = try self.slotFacetParser(slot: slot, whitespaceIndices: tokenIndices, encoder: encoder, encodedTokens: encodedTokens)
                slots[slot.name] = Slot(type: slot.type, value: parsed.value, rawValue: parsed.rawValue)
            } else {
                // no match, so create an empty slot
                slots[slot.name] = Slot(type: slot.type, value: nil, rawValue: nil)
            }
        }
        return slots
    }
    
    private func slotFacetParser(slot: NLUTensorflowSlot, whitespaceIndices: [Int], encoder: BertTokenizer, encodedTokens: EncodedTokens) throws -> (value: Any?, rawValue: String?) {
        switch slot.type {
        case "selset":
            // filter the slot selection aliases (and the slot selection name itself) to see if they match any tokens
            guard let parsed = try slot.parsed() as? NLUTensorflowSelset else {
                throw NLUError.metadata("The NLU metadata for the \(slot.name) slot was not found.")
            }
            let decoded = try encoder
                .decodeWithWhitespace(encodedTokens: encodedTokens, whitespaceIndices: whitespaceIndices)
                .trimmingCharacters(in: .punctuationCharacters)
            let contains = parsed.selections.filter { selection in
                selection.name == decoded || selection.aliases.contains(decoded)
            }
            // just pick the first, if any, that matched
            return (contains.first?.name, decoded)
        case "integer":
            guard let parsed = try slot.parsed() as? NLUTensorflowInteger else {
                throw NLUError.metadata("The NLU metadata for the \(slot.name) slot was not found.")
            }
            let decoded = try encoder
                .decode(encodedTokens: encodedTokens, whitespaceIndices: whitespaceIndices)
            let integer = decoded
                .reduce([], { self.parseReduceNumber($0, next: $1) })
                .reduce(0, { $0 + $1 })
            guard let lowerBound = parsed.range.first,
                let upperBound = parsed.range.last
                else {
                    return (nil, decoded.joined(separator: " "))
            }
            let range = lowerBound...upperBound
            return (range.contains(integer) ? integer : nil, decoded.joined(separator: " "))
        case "digits":
            guard let parsed = try slot.parsed() as? NLUTensorflowDigits else {
                throw NLUError.metadata("The NLU metadata for the \(slot.name) slot was not found.")
            }
            let decoded = try encoder
                .decode(encodedTokens: encodedTokens, whitespaceIndices: whitespaceIndices)
            let digits = decoded
                .map({ value in
                    if let cardinal = self.wordToNumber(value) {
                        return cardinal as String
                    } else {
                        return value as String
                    }
                })
                .joined()
            return (parsed.count == digits.count ? digits : nil, decoded.joined(separator: " "))
        case "entity":
            let v = try encoder.decodeWithWhitespace(encodedTokens: encodedTokens, whitespaceIndices: whitespaceIndices)
            return (v,v)
        default:
            return (nil, nil)
        }
    }
    
    private func parseReduceNumber(_ accumulation: [Int], next: String) -> [Int] {
        if next.count == 0 {
            return accumulation
        } else if let int = Int(next) {
            return accumulation + [int]
        } else if let multiplier = Int(multipliersToNumber[next] ?? "") {
            return self.collapse(accumulation, multiplier: multiplier)
        } else if let cardinal = Int(wordToNumber(next) ?? "") {
            return accumulation + [cardinal]
        } else {
            return accumulation
        }
    }
    
    private func collapse(_ accumulation: [Int], multiplier: Int) -> [Int] {
        var sum = 0
        let result: [Int] = accumulation.compactMap { value in
            if value > multiplier {
                return value
            } else {
                sum += value
                return nil
            }
        }
        sum = max(sum, 1)
        return result + [sum * multiplier]
    }
    
    private func parseNumber(_ text: String) -> Int? {
        if text.count == 0 {
            return nil
        } else if let int = Int(text) {
            return int
        } else if let cardinal = Int(wordToNumber(text) ?? "") {
            return cardinal
        } else {
            return nil
        }
    }
    
    private func wordToNumber(_ text: String) -> String? {
        if text.suffix(2) == "th" {
            return self.wordToNumber[String(text.prefix(text.count - 2))]
        } else {
            return self.wordToNumber[text]
        }
    }
    
    private let wordToNumber = [
        "oh" : "0",
        "owe" : "0",
        "zero" : "0",
        "one" : "1",
        "won" : "1",
        "fir" : "1",
        "first": "1",
        "two" : "2",
        "seco" : "2",
        "to" : "2",
        "too" : "2",
        "second": "2",
        "three" : "3",
        "thi" : "3",
        "third": "3",
        "four" : "4",
        "for" : "4",
        "fore" : "4",
        "five" : "5",
        "fif" : "5",
        "six" : "6",
        "sicks" : "6",
        "sics" : "6",
        "seven" : "7",
        "eight" : "8",
        "eigh" : "8",
        "ate" : "8",
        "nine" : "9",
        "nin" : "9",
        "ten" : "10",
        "tin" : "10",
        "eleven" : "11",
        "twelve" : "12",
        "twelf" : "12",
        "thirteen": "13",
        "fourteen": "14",
        "fifteen": "15",
        "sixteen": "16",
        "seventeen": "17",
        "eighteen": "18",
        "nineteen": "19",
        "twenty" : "20",
        "twentie" : "20",
        "thirty" : "30",
        "thirtie" : "30",
        "forty" : "40",
        "fortie" : "40",
        "fifty" : "50",
        "fiftie" : "50",
        "sixty" : "60",
        "sixtie" : "60",
        "seventy" : "70",
        "seventie" : "70",
        "eighty" : "80",
        "eightie": "80",
        "ninety" : "90",
        "ninetie": "90",
        "hundred" : "100",
        "thousand" : "1000",
        "million" : "1000000",
        "billion" : "1000000000"
    ]
    
    private let multipliersToNumber = [
        "hundred" : "100",
        "thousand" : "1000",
        "million" : "1000000",
        "billion" : "1000000000"
    ]
}
