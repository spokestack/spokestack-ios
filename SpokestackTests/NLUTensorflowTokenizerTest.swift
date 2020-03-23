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
        XCTAssertEqual(t2.encoded, [72])
        
        let t3 = try! tokenizer.encode(text: "theres")
        XCTAssertEqual(t3.encoded, [56, 26])
        
        let t4 = "With her from — the one: this also has?"
        let tokens = ["With", "her", "from", "—", "the", "one:", "this", "also", "has?"]
        XCTAssertEqual(try! tokenizer.encode(text: t4).tokensByWhitespace, tokens)
        
        let phone = "4238341745"
        let phoneTokens = [63, 69, 68, 67, 70]
        XCTAssertEqual(try! tokenizer.encode(text: phone).encoded, phoneTokens)
    
        let text = "With her from—the one: this also has?"
        let encoded = [18, 25, 24, 1, 7, 39, 4, 34, 47, 49, 5]
        let indices = [0, 1, 2, 2, 2, 3, 3, 4, 5, 6, 6]
        let wt = ["With", "her", "from—the", "one:", "this", "also", "has?"]
        let et = try! tokenizer.encode(text: text)
        XCTAssertEqual(et.encoded, encoded)
        XCTAssertEqual(et.encodedTokensByWhitespaceIndex, indices)
        XCTAssertEqual(et.tokensByWhitespace, wt)
    }
    
    func testBertTokenizerDecodeWithWhitespace() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        
        let t1 = "Godspeed You! Black Emperor"
        let et1 = EncodedTokens(tokensByWhitespace: ["Godspeed", "You!", "Black", "Emperor"], encodedTokensByWhitespaceIndex: [0], encoded: [])
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: et1, whitespaceIndices: Array(0...3)), t1)

        let t2 = "their"
        let et2 = EncodedTokens(tokensByWhitespace: [t2], encodedTokensByWhitespaceIndex: [0], encoded: [48])
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: et2, whitespaceIndices: [0]), t2)
        
        let t3 = "theres"
        let et3 = EncodedTokens(tokensByWhitespace: [t3], encodedTokensByWhitespaceIndex: [0,0], encoded: [56, 26])
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: et3, whitespaceIndices: [0]), t3)
    }
    
    func testBertEncodeDecodeRoundtrip() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let t1 = "this also has"
        XCTAssertEqual(try! tokenizer.decodeWithWhitespace(encodedTokens: try! tokenizer.encode(text: t1), whitespaceIndices: Array(0...2)), t1)
        
        let text = "With her from—the one: this also has?"
        let et = try! tokenizer.encode(text: text)
        let decodedFull = try! tokenizer.decodeWithWhitespace(encodedTokens: et, whitespaceIndices: Array(0...et.tokensByWhitespace.count-1))
        XCTAssertEqual(decodedFull, text)
        let decodedPartial = try! tokenizer.decodeWithWhitespace(encodedTokens: et, whitespaceIndices: [1,2])
        XCTAssertEqual(decodedPartial, "her from—the")
        
        let t2 = "Ålesund ~firsts"
        let et2 = try! tokenizer.encode(text: t2)
        let d2 = try! tokenizer.decodeWithWhitespace(encodedTokens: et2, whitespaceIndices: Array(0...et2.tokensByWhitespace.count-1))
        XCTAssertEqual(d2, t2)
    }
}
