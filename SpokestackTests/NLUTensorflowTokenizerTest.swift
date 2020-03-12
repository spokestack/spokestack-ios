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

    func testBertTokenize() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        
        let t2 = tokenizer.tokenize(text: "thereunto")
        XCTAssertEqual(t2, ["[UNK]"])
        
        let t3 = tokenizer.tokenize(text: "theres")
        XCTAssertEqual(t3, ["there", "##s"])
        
        let t4 = "With her from — the one: this also has?"
        let tokens = ["with", "her", "from", "—", "the", "one", ":", "this", "also", "has", "?"]
        XCTAssertEqual(tokenizer.tokenize(text: t4), tokens)
        
        let phone = "4238341745"
        let phoneTokens = ["42", "##38", "##34", "##17", "##45"]
        XCTAssertEqual(tokenizer.tokenize(text: phone), phoneTokens)
    }
    
    func testBertDecode() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        XCTAssertEqual(tokenizer.decode(["God", "##speed", "You", "!", "Black", "Emperor"]), ["Godspeed", "You", "!", "Black", "Emperor"])

        XCTAssertEqual(tokenizer.decode(["their"]), ["their"])
        
        XCTAssertEqual(tokenizer.decode(["there", "##s"]), ["theres"])
    }
    
    func testBertTokenizeDecodeRoundtrip() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        XCTAssertEqual(tokenizer.decode(tokenizer.tokenize(text: "this also has")), ["this", "also", "has"])
    }
    
    func testBertTokenizerEncode() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "With her from—the one: this also has?"
        let encoded = [18, 25, 24, 1, 7, 39, 4, 34, 47, 49, 5]
        XCTAssertEqual(try! tokenizer.encode(tokens: tokenizer.tokenize(text: text)), encoded)
    }
}
