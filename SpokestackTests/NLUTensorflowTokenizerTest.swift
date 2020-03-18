//
//  NLUTensorflowTokenizerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 1/24/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import XCTest
import Spokestack

class NLUTensorflowTokenizerTest: XCTestCase {

    func testBertTokenizerEncode() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        
        let t2 = try! tokenizer.encode(text: "thereunto")
        //XCTAssertEqual(t2.normalizedTokens, ["[UNK]"])
        
        let t3 = try! tokenizer.encode(text: "theres")
        //XCTAssertEqual(t3.normalizedTokens, ["there", "##s"])
        
        let t4 = "With her from — the one: this also has?"
        let tokens = ["with", "her", "from", "—", "the", "one", ":", "this", "also", "has", "?"]
        //XCTAssertEqual(try! tokenizer.encode(text: t4).normalizedTokens, tokens)
        
        let phone = "4238341745"
        let phoneTokens = ["42", "##38", "##34", "##17", "##45"]
        //XCTAssertEqual(try! tokenizer.encode(text: phone).normalizedTokens, phoneTokens)
    
        let text = "With her from—the one: this also has?"
        let encoded = [18, 25, 24, 1, 7, 39, 4, 34, 47, 49, 5]
        let indicies = [0, 1, 2, 2, 2, 3, 3, 4, 5, 6, 6]
        let wt = ["With", "her", "from—the", "one:", "this", "also", "has?"]
        let et = try! tokenizer.encode(text: text)
        XCTAssertEqual(et.encodedTokens, encoded)
        XCTAssertEqual(et.encodedTokensByWhitespaceIndex, indicies)
        XCTAssertEqual(et.tokensByWhitespace, wt)
    }
    
    func testBertTokenizerdecodeWithWhitespace() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        
        let t1 = "Godspeed You! Black Emperor"
        let tw1 = ["Godspeed", "You!", "Black", "Emperor"]
        let etw1 = [0]
        let etet1 = [0]
        let et1 = EncodedTokens(tokensByWhitespace: tw1, encodedTokensByWhitespaceIndex: etw1, encodedTokens: etet1)
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: et1, whitespaceIndicies: Array(0...3)), t1)

        var et2 = EncodedTokens()
        let t2 = "their"
        et2.tokensByWhitespace = [t2]
        et2.encodedTokensByWhitespaceIndex = [0]
        et2.encodedTokens = [48]
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: et2, whitespaceIndicies: [0]), t2)
        
        var et3 = EncodedTokens()
        let t3 = "theres"
        et3.tokensByWhitespace = [t3]
        et3.encodedTokensByWhitespaceIndex = [0,0]
        et3.encodedTokens = [56, 26]
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: et3, whitespaceIndicies: [0]), t3)
    }
    
    func testBertEncodeDecodeRoundtrip() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let t1 = "this also has"
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: try! tokenizer.encode(text: t1), whitespaceIndicies: Array(0...2)), t1)
        
        let text = "With her from—the one: this also has?"
        let et = try! tokenizer.encode(text: text)
        let decodedFull = try! tokenizer.decodeWithWhitespace(encodedTokens: et, whitespaceIndicies: Array(0...et.tokensByWhitespace!.count-1))
        XCTAssertEqual(decodedFull, text)
        let decodedPartial = try! tokenizer.decodeWithWhitespace(encodedTokens: et, whitespaceIndicies: [1,2])
        XCTAssertEqual(decodedPartial, "her from—the")
    }
}
