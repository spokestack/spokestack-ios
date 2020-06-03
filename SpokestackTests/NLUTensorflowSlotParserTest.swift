//
//  NLUTensorflowSlotParserTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 2/25/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import Spokestack
import XCTest

class NLUTensorflowSlotParserTest: XCTestCase {

    let parser = NLUTensorflowSlotParser()
    var encoder: BertTokenizer?
    var metadata: NLUTensorflowMetadata?
    
    override func setUp() {
        super.setUp()
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        self.encoder = try! BertTokenizer(config)
        let metaData = createMetadata().data(using: .utf8)
        self.metadata = try! JSONDecoder().decode(NLUTensorflowMetadata.self, from: metaData!)
    }
    
    func testParseSelset() {
        let et = EncodedTokens(tokensByWhitespace: ["kitchen"], encodedTokensByWhitespaceIndex: [0], encoded: [])
        let parsedSelset = try! parser.parse(tags: ["b_location"], intent: metadata!.intents.filter({ $0.name == "request.lights.deactivate" }).first!, encoder: encoder!, encodedTokens: et)
        XCTAssertEqual(parsedSelset!["location"]!.value as! String, "room")
        
        // selset value has appended punctuation
        let et2 = EncodedTokens(tokensByWhitespace: ["kitchen."], encodedTokensByWhitespaceIndex: [0], encoded: [])
        let parsedSelset2 = try! parser.parse(tags: ["b_location"], intent: metadata!.intents.filter({ $0.name == "request.lights.deactivate" }).first!, encoder: encoder!, encodedTokens: et2)
        XCTAssertEqual(parsedSelset2!["location"]!.value as! String, "room")
    }
    
    func testParseInteger() {
        let et1 = EncodedTokens(tokensByWhitespace: ["ten"], encodedTokensByWhitespaceIndex: [0], encoded: [])
        let parsedInteger10 = try! parser.parse(tags: ["b_rating"], intent: metadata!.intents.filter({ $0.name == "rate.app" }).first!, encoder: encoder!, encodedTokens: et1)
        XCTAssertEqual(parsedInteger10!["rating"]!.value as! Int, 10)
        
        let et2 = EncodedTokens(tokensByWhitespace: ["fiftie", "one"],  encodedTokensByWhitespaceIndex: [0, 0, 0, 1], encoded: [])
        let parsedInteger51 = try! parser.parse(tags: ["b_rating", "i_rating", "i_rating", "i_rating"], intent: metadata!.intents.filter({ $0.name == "rate.app" }).first!, encoder: encoder!, encodedTokens: et2)
        XCTAssertEqual(parsedInteger51!["rating"]!.value as! Int, 51)

        let et3 = EncodedTokens(tokensByWhitespace: ["fiftie", "six"],  encodedTokensByWhitespaceIndex: [0, 0, 0, 1], encoded: [])
        let parsedIntegerNil = try! parser.parse(tags: ["b_rating", "i_rating", "i_rating", "i_rating"], intent: metadata!.intents.filter({ $0.name == "rate.app" }).first!, encoder: encoder!, encodedTokens: et3)
        XCTAssertNil(parsedIntegerNil!["rating"]!.value)
        
        let et4 = EncodedTokens(tokensByWhitespace: ["one", "million"], encodedTokensByWhitespaceIndex: [0, 1], encoded: [])
        let intent = metadata!.intents.filter({ $0.name == "i.i" }).first!
        let parsedIntegerMillion = try! parser.parse(tags: ["b_iMi", "i_iMi"], intent: intent, encoder: encoder!, encodedTokens: et4)
        XCTAssertEqual(parsedIntegerMillion!["iMi"]!.value as! Int, 1000000)
    }
    
    func testParseDigits() {
        let taggedInputPhoneNumeric = ["b_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number"]
        let et5 = EncodedTokens(tokensByWhitespace: ["4238341746"], encodedTokensByWhitespaceIndex: [0, 0, 0, 0, 0], encoded: [])
        let parsedDigitsNumeric = try! parser.parse(tags: taggedInputPhoneNumeric, intent: metadata!.intents.filter({ $0.name == "inform.phone_number" }).first!, encoder: encoder!, encodedTokens: et5)
        XCTAssertEqual(parsedDigitsNumeric!["phone_number"]!.value as! String, "4238341746")

        let taggedInputPhoneCardinal = ["b_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number"]
        let et6 = EncodedTokens(tokensByWhitespace: ["4", "second", "three", "eighth", "three", "four", "one", "seven", "four", "six"], encodedTokensByWhitespaceIndex: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], encoded: [])
        let parsedDigitsCardinal = try! parser.parse(tags: taggedInputPhoneCardinal, intent: metadata!.intents.filter({ $0.name == "inform.phone_number" }).first!, encoder: encoder!, encodedTokens: et6)
        XCTAssertEqual(parsedDigitsCardinal!["phone_number"]!.value as! String, "4238341746")
    }
    
    func testParseEntity() {
        let taggedInputEntity = ["b_eponymous", "i_eponymous"]
        let et1 = EncodedTokens(tokensByWhitespace: ["dead", "beef"], encodedTokensByWhitespaceIndex: [0, 1], encoded: [])
        let parsedEntity = try! parser.parse(tags: taggedInputEntity, intent: metadata!.intents.filter({ $0.name == "identify" }).first!, encoder: encoder!, encodedTokens: et1)
        XCTAssertEqual(parsedEntity!["eponymous"]!.value as! String, "dead beef")
        
        let taggedInputEntityO = ["o", "b_eponymous", "i_eponymous", "o", "o", "b_eponymous", "o"]
        let etO = EncodedTokens(tokensByWhitespace: ["when", "dead", "beef", "appears", "in", "debug"], encodedTokensByWhitespaceIndex: [0, 1, 2, 3, 4, 5], encoded: [])
        let parsedEntityO = try! parser.parse(tags: taggedInputEntityO, intent: metadata!.intents.filter({ $0.name == "identify" }).first!, encoder: encoder!, encodedTokens: etO)
        XCTAssertEqual(parsedEntityO!["eponymous"]!.value as! String, "dead beef debug")
    }
    
    func testParseUnspecifiedSlot() {
        // Slots not declared by an intent but tagged by the model do not cause an error and are not returned to the caller
        let taggedInput = ["o", "b_eponymous"]
        let et = EncodedTokens(tokensByWhitespace: ["hey", "ma"], encodedTokensByWhitespaceIndex: [0, 1], encoded: [])
        let parsed = try! parser.parse(tags: taggedInput, intent: metadata!.intents.filter({ $0.name == "i.i" }).first!, encoder: encoder!, encodedTokens: et)
        XCTAssertNil(parsed!["iMi"]!.value)
        
        // Slots declared by an intent but not tagged by the model are returned to the caller in the output with a nil value
        let taggedInputEmpty = ["o", "o"]
        let parsedEmpty = try! parser.parse(tags: taggedInputEmpty, intent: metadata!.intents.filter({ $0.name == "i.i" }).first!, encoder: encoder!, encodedTokens: et)
        XCTAssertNil(parsedEmpty!["iMi"]!.value)
    }
    
    func createMetadata() -> String {
        return #"""
        {
          "intents": [
            {
              "name": "request.lights.deactivate",
              "slots": [
                {
                  "name": "location",
                  "type": "selset",
                  "facets": "{\"selections\": [{\"name\": \"room\", \"aliases\": [\"kitchen\", \"bedroom\", \"washroom\"]}]}"
                }
              ]
            },
            {
              "name": "rate.app",
              "slots": [
                {
                  "name": "rating",
                  "type": "integer",
                  "facets": "{\"range\": [1, 52]}"
                }
              ]
            },
            {
              "name": "i.i",
              "slots": [
                {
                  "name": "iMi",
                  "type": "integer",
                  "facets": "{\"range\": [1, 1000000]}"
                }
              ]
            },            {
              "name": "inform.phone_number",
              "slots": [
                {
                  "name": "phone_number",
                  "type": "digits",
                  "facets": "{\"count\": 10}"
                }
              ]
            },
            {
              "name": "identify",
              "slots": [
                {
                  "name": "eponymous",
                  "type": "entity"
                }
              ]
            }
          ],
          "tags": [
            "o",
            "b_rating",
            "i_rating",
            "b_iMi",
            "i_iMi",
            "b_location",
            "i_location",
            "b_phone_number",
            "i_phone_number",
            "b_eponymous",
            "i_eponymous"
          ]
        }
"""#
    }
}
