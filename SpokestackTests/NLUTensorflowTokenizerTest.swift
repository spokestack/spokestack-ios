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
    
    func testWordpieceTokenize() {
        let tokenizer = WordpieceTokenizer(try! SharedTestMocks.createEncodingsDictionary(SharedTestMocks.createVocabularyPath()))
        let t1 = tokenizer.tokenize("their")
        XCTAssertEqual(t1, ["their"])
        
        let t2 = tokenizer.tokenize("thereunto")
        XCTAssertEqual(t2, ["[UNK]"])
        
        let t3 = tokenizer.tokenize("theres")
        XCTAssertEqual(t3, ["there", "##s"])
    }
    
    func testWordpieceDetokenize() {
        let tokenizer = WordpieceTokenizer(try! SharedTestMocks.createEncodingsDictionary(SharedTestMocks.createVocabularyPath()))
        
        XCTAssertEqual(tokenizer.detokenize(["their"]), "their")
        
        XCTAssertEqual(tokenizer.detokenize(["there", "##s"]), "theres")
        
        XCTAssertEqual(tokenizer.detokenize(["there", "unto"]), "there unto")
    }
    
    func testBertTokenize() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "With her from — the one: this also has?"
        let tokens = ["with", "her", "from", "—", "the", "one", ":", "this", "also", "has", "?"]
        XCTAssertEqual(tokenizer.tokenize(text), tokens)
        
        let phone = "4238341745"
        let phoneTokens = ["42", "##38", "##34", "##17", "##45"]
        XCTAssertEqual(tokenizer.tokenize(phone), phoneTokens)
    }
    
    func testBertDetokenize() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        XCTAssertEqual(tokenizer.detokenize(["God", "##speed", "You", "!", "Black", "Emperor"]), "Godspeed You! Black Emperor")

    }
    
    func testBertTokenizeDetokenizeRoundtrip() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "this also has"
        XCTAssertEqual(tokenizer.detokenize(tokenizer.tokenize(text)), text)
    }
    
    func testBertTokenizerEncode() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "With her from—the one: this also has?"
        let encoded = [18, 25, 24, 1, 7, 39, 4, 34, 47, 49, 5]
        XCTAssertEqual(try! tokenizer.encode(tokenizer.tokenize(text)), encoded)
    }
}
