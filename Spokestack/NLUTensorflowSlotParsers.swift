//
//  NLUTensorflowSlotParsers.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/25/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Provides a parser for reconstructing tensorflow nlu slot values from the input and IOB tag labels.
internal struct NLUTensorflowSlotParser {
    
    /// Parse the classification input and predicted tag labels into a structured [intent : Slot] dictionary.
    /// - Note: This operation effectively truncates the tag labels by the input size, ignoring all labels outside the input token count.
    /// - Parameters:
    ///   - taggedInput: A zip of tokenized inputs and classification tag labels.
    ///   - intent: The predicted intent.
    internal func parse(taggedInput: Zip2Sequence<[String], [String]>, intent: NLUTensorflowIntent, encoder: BertTokenizer) throws -> [String:Slot] {
        
        var slots: [String:Slot] = [:]
        
        // create a dictionary of [tags: [tokens]]
        var slotTokens: [String:[String]] = [:]
        for (tag, token) in taggedInput {
            // the model slot recognizer uses IOB tags, so `b_` and `i_` prefixes must be removed to resolve tag labels to slot names.
            var slotType = tag
            if let prefixIndex = tag.range(of: "_")?.upperBound {
                slotType = String(tag.suffix(from: prefixIndex))
            }
            // collect all the tokens with the same slot type into a single array
            slotTokens[slotType, default: []] += [token]
        }
        // for each tag that isn't unclassified, send the tokens to the slot facet parser
        for (name, values) in slotTokens where name != "o" {
            guard let slot = intent.slots.filter({ $0.name == name }).first else {
                throw NLUError.metadata("Could not find a slot called \(name) in nlu metadata.")
            }
            let slotValue = try self.slotFacetParser(slot: slot, values: values, encoder: encoder)

            slots[name] = Slot(type: slot.type, value: slotValue)
        }
        
        return slots
    }
    
    private func slotFacetParser(slot: NLUTensorflowSlot, values: [String], encoder: BertTokenizer) throws -> Any? {
        switch slot.type {
        case "selset":
            // filter the slot selection aliases (and the slot selection name itself) to see if they match any tokens
            guard let parsed = try slot.parsed() as? NLUTensorflowSelset else {
                throw NLUError.metadata("The NLU metadata for the \(slot.name) facet was not found.")
            }
            let decoded = encoder.detokenize(values)
            let contains = parsed.selections.filter { selection in
                selection.name == decoded || selection.aliases.contains(decoded)
            }
            // just pick the first, if any, that matched
            return contains.first?.name
        case "integer":
            guard let parsed = try slot.parsed() as? NLUTensorflowInteger else {
                throw NLUError.metadata("The NLU metadata for the \(slot.name) facet was not found.")
            }
            let integer = encoder
                .decode(values)
                .reduce([], { self.parseReduceNumber($0, next: $1) })
                .reduce(0, { $0 + $1 })
            guard let lowerBound = parsed.range.first,
                let upperBound = parsed.range.last
                else {
                return nil
            }
            let range = ClosedRange<Int>(uncheckedBounds: (lower: lowerBound, upper: upperBound))
            return range.contains(integer) ? integer : nil
        case "digits":
            guard let parsed = try slot.parsed() as? NLUTensorflowDigits else {
                throw NLUError.metadata("The NLU metadata for the \(slot.name) facet was not found.")
            }
            let digits = encoder
                .decode(values)
                .map({ value in
                    if let cardinal = self.wordToNumber(value) {
                        return cardinal as String
                    } else {
                        return value as String
                    }
                })
                .joined()
            return parsed.count == digits.count ? digits : nil
        case "entity":
            return encoder.detokenize(values)
        default:
            return nil
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
