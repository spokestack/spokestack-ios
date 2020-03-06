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
        let taggedInputLocation = zip(["b_location"],["kitchen"])
        let parsedSelset = try! parser.parse(taggedInput: taggedInputLocation, intent: metadata!.intents.filter({ $0.name == "request.lights.deactivate" }).first!, encoder: encoder!)
        XCTAssertEqual(parsedSelset["location"]!.value as! String, "room")
    }
    
    func testParseInteger() {
        let taggedInputRating10 = zip(["b_rating"],["ten"])
        let parsedInteger10 = try! parser.parse(taggedInput: taggedInputRating10, intent: metadata!.intents.filter({ $0.name == "rate.app" }).first!, encoder: encoder!)
        XCTAssertEqual(parsedInteger10["rating"]!.value as! Int, 10)
        
        let taggedInputRating51 = zip(["b_rating", "i_rating", "i_rating", "i_rating"],["fi","##ft", "##ie", "one"])
        let parsedInteger51 = try! parser.parse(taggedInput: taggedInputRating51, intent: metadata!.intents.filter({ $0.name == "rate.app" }).first!, encoder: encoder!)
        XCTAssertEqual(parsedInteger51["rating"]!.value as! Int, 51)

        let taggedInputRatingNil = zip(["b_rating", "i_rating", "i_rating", "i_rating"],["fi","##ft", "##ie", "six"])
        let parsedIntegerNil = try! parser.parse(taggedInput: taggedInputRatingNil, intent: metadata!.intents.filter({ $0.name == "rate.app" }).first!, encoder: encoder!)
        XCTAssertNil(parsedIntegerNil["rating"]!.value)
        
        let taggedInputRatingMillion = zip(["b_iMi", "i_iMi"],["one", "million"])
        let intent = metadata!.intents.filter({ $0.name == "i.i" }).first!
        let parsedIntegerMillion = try! parser.parse(taggedInput: taggedInputRatingMillion, intent: intent, encoder: encoder!)
        XCTAssertEqual(parsedIntegerMillion["iMi"]!.value as! Int, 1000000)
        
    }
    
    func testParseDigits() {
        let taggedInputPhoneNumeric = zip(["b_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number"],["42", "##38", "##34", "##17", "##45"])
        let parsedDigitsNumeric = try! parser.parse(taggedInput: taggedInputPhoneNumeric, intent: metadata!.intents.filter({ $0.name == "inform.phone_number" }).first!, encoder: encoder!)
        XCTAssertEqual(parsedDigitsNumeric["phone_number"]!.value as! String, "4238341745")

        let taggedInputPhoneCardinal = zip(["b_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number"],["4", "second", "three", "eighth", "three", "four", "one", "seven", "four", "five"])
        let parsedDigitsCardinal = try! parser.parse(taggedInput: taggedInputPhoneCardinal, intent: metadata!.intents.filter({ $0.name == "inform.phone_number" }).first!, encoder: encoder!)
        XCTAssertEqual(parsedDigitsCardinal["phone_number"]!.value as! String, "4238341745")
    }
    
    func testParseEntity() {
        let taggedInputEntity = zip(["b_epynonymous", "i_epynonymous"],["dead", "beef"])
        let parsedEntity = try! parser.parse(taggedInput: taggedInputEntity, intent: metadata!.intents.filter({ $0.name == "identify" }).first!, encoder: encoder!)
        XCTAssertEqual(parsedEntity["epynonymous"]!.value as! String, "dead beef")
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
                  "name": "epynonymous",
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
            "b_epynonymous",
            "i_epynonymous"
          ]
        }
"""#
    }
}
