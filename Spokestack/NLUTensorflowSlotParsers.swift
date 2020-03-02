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
    private var tokenizer: BertTokenizer?
    private let decoder = JSONDecoder()
    
    /// Initializes a slot parser for the specific nlu tensorflow model.
    /// - Parameters:
    ///   - configuration: The global SpeechConfiguration object.
    ///   - inputMaxTokenLength: The maximum number of input tokens to the nlu tensorflow model.
    init(configuration: SpeechConfiguration, inputMaxTokenLength: Int) throws {
        self.tokenizer = try BertTokenizer(configuration)
        self.tokenizer?.maxTokenLength = inputMaxTokenLength
    }
    
    /// Parse the classification input and predicted tag labels into a structured [intent : Slot] dictionary.
    /// - Note: This operation effectively truncates the tag labels by the input size, ignoring all labels outside the input token count.
    /// - Parameters:
    ///   - taggedInput: A zip of tokenized inputs and classification tag labels.
    ///   - intent: The predicted intent.
    internal func parse(taggedInput: Zip2Sequence<[String], [String]>, intent: NLUTensorflowIntent) throws -> [String:Slot] {
        
        var slots: [String:Slot] = [:]
        
        // create a dictionary of [tags: [tokens]]
        var slotTokens: [String:[String]] = [:]
        for (tag, token) in taggedInput {
            // the model slot recognizer uses IOB tags, so `b_` and `i_` prefixes must be removed to resolve tag labels to slot names.
            var slotType = tag
            if let prefixIndex = tag.range(of: "_")?.upperBound {
                slotType = String(tag.suffix(from: prefixIndex))
            }
            // collect all the tokens, detokenized, with the same slot type into a single array
            if let tokens = slotTokens[slotType] {
                if let value = try tokenizer?.detokenize([token]) {
                    slotTokens[slotType] = tokens + [value]
                }
            } else {
                slotTokens[slotType] = [token]
            }
        }
        // for each tag that isn't unclassified, send the tokens to the slot facet parser
        for slotName in slotTokens.keys where slotName != "o" {
            guard let slot = intent.slots.filter({ $0.name == slotName }).first else {
                throw NLUError.metadata("Could not find a slot called \(slotName) in nlu metadata.")
            }
            guard let facetData = slot.facets.data(using: .utf16) else {
                throw NLUError.metadata("Error when converting \(slotName) facet data.")
            }
            let slotValue = try self.slotFacetParser(slot: slot, facetData: facetData, values: slotTokens[slotName])

            slots[slotName] = Slot(type: slot.type, value: slotValue)
        }
        
        return slots
    }
    
    private func slotFacetParser(slot: NLUTensorflowSlot, facetData: Data, values: [String]?) throws -> Any? {
        guard let text = values else {
            return nil
        }
        switch slot.type {
        case "selset":
            let parsedSlot = try decoder.decode(NLUTensorflowSelset.self, from: facetData)
            // filter the slot selection aliases to see if they match any tokens
            let contains = parsedSlot.selections.filter { selection in
                text.contains(where: { name in
                    selection.aliases.contains(where: { alias in
                        name == alias
                    })
                })
            }
            // just pick the first, if any, that matched
            return contains.first?.name
        case "integer":
            let parsedSlot = try decoder.decode(NLUTensorflowInteger.self, from: facetData)
            guard let lowerBound = parsedSlot.range.first,
                let upperBound = parsedSlot.range.last,
                let parsedValue = parseNumber(text)
                else {
                return nil
            }
            let range = ClosedRange<Int>(uncheckedBounds: (lower: lowerBound, upper: upperBound))
            return range.contains(parsedValue) ? parsedValue : nil
        case "digits":
            let parsedSlot = try decoder.decode(NLUTensorflowDigits.self, from: facetData)
            let number = text.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).joined()
            return parsedSlot.count == number.count ? number : nil
        default:
            return nil
        }
    }
    
    private func parseNumber(_ text: [String]) -> Int? {
        let number = text.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).joined()
        if let int = Int(number) {
            return int
        } else if text.count == 0 {
            return nil
        } else if let cardinal = parseCardinal(text) {
            return cardinal
        } else {
            return nil
        }
    }
    
    private func parseCardinal(_ text: [String]) -> Int? {
        let numbers = text.compactMap { self.cardinalToNumber[$0] }
        return Int(numbers.joined())
    }
    
    private let cardinalToNumber = [
        "zero" : "0",
        "oh" : "0",
        "owe" : "0",
        "one" : "1",
        "fir" : "1",
        "won" : "1",
        "two" : "2",
        "seco" : "2",
        "to" : "2",
        "too" : "2",
        "three" : "3",
        "thi" : "3",
        "thir" : "3",
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
        "twenty" : "20",
        "twentie" : "20",
        "thirty" : "30",
        "thirtie" : "30",
        "forty" : "40",
        "fortie" : "40",
        "fifty" : "50",
        "fiftie" : "50",
        "sixty" : "6",
        "seventy" : "7",
        "eighty" : "8",
        "ninety" : "9",
        "hundred" : "2",
        "thousand" : "3",
    ]
}
