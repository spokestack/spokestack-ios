//
//  SlotParserTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 2/25/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import Spokestack
import XCTest

class SlotParserTest: XCTestCase {
    
    func testParse() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let parser = try! NLUSlotParser(configuration: config, inputMaxTokenLength: 100)
        let metaData = createMetadata().data(using: .utf8)
        let metadata = try! JSONDecoder().decode(NLUModelMetadata.self, from: metaData!)
        
        // selset parse
        let taggedInputLocation = zip(["b_location"],["kitchen"])
        let parsedSelset = try! parser.parse(taggedInput: taggedInputLocation, intent: metadata.intents.filter({ $0.name == "request.lights.deactivate" }).first!)
        XCTAssertEqual(parsedSelset["location"]!.value as! String, "room")
        
        // integer parse
        let taggedInputRating = zip(["b_rating"],["ten"])
        let parsedInteger = try! parser.parse(taggedInput: taggedInputRating, intent: metadata.intents.filter({ $0.name == "rate.app" }).first!)
        XCTAssertEqual(parsedInteger["rating"]!.value as! Int, 10)
        
        // digits parse
        let taggedInputPhone = zip(["b_phone_number", "i_phone_number", "i_phone_number", "i_phone_number", "i_phone_number"],["42", "##38", "##34", "##17", "##45"])
        let parsedDigits = try! parser.parse(taggedInput: taggedInputPhone, intent: metadata.intents.filter({ $0.name == "inform.phone_number" }).first!)
        XCTAssertEqual(parsedDigits["phone_number"]!.value as! String, "4238341745")
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
                  "facets": "{\"range\": [1, 10]}"
                }
              ]
            },
            {
              "name": "inform.phone_number",
              "slots": [
                {
                  "name": "phone_number",
                  "type": "digits",
                  "facets": "{\"count\": 10}"
                }
              ]
            }
          ],
          "tags": [
            "o",
            "b_rating",
            "i_rating",
            "b_location",
            "i_location",
            "b_phone_number",
            "i_phone_number"
          ]
        }
"""#
    }
}
