//
//  TokenizerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 1/24/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import XCTest
import Spokestack

class TokenizerTest: XCTestCase {
    
    func testWordpieceTokenize() {
        let tokenizer = WordpieceTokenizer(try! createEncodingsDictionary(createVocabularyPath()))
        let t1 = tokenizer.tokenize("their")
        XCTAssertEqual(t1, ["their"])
        
        let t2 = tokenizer.tokenize("thereunto")
        XCTAssertEqual(t2, ["[UNK]"])
        
        let t3 = tokenizer.tokenize("theres")
        XCTAssertEqual(t3, ["there", "##s"])
    }
    
    func testWordpieceDetokenize() {
        let tokenizer = WordpieceTokenizer(try! createEncodingsDictionary(createVocabularyPath()))
        
        XCTAssertEqual(try tokenizer.detokenize(["their"]), "their")
        
        XCTAssertEqual(try tokenizer.detokenize(["there", "##s"]), "theres")
        
        XCTAssertEqual(try tokenizer.detokenize(["there", "unto"]), "there unto")
    }
    
    func testBertTokenize() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "With her from — the one: this also has?"
        let tokens = ["with", "her", "from", "—", "the", "one", ":", "this", "also", "has", "?"]
        XCTAssertEqual(tokenizer.tokenize(text), tokens)
        
        let phone = "4238341745"
        let phoneTokens = ["42", "##38", "##34", "##17", "##45"]
        XCTAssertEqual(tokenizer.tokenize(phone), phoneTokens)
    }
    
    func testBertTokenizeDetokenizeRoundtrip() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "this also has"
        XCTAssertEqual(try tokenizer.detokenize(tokenizer.tokenize(text)), text)
    }
    
    func testBertTokenizerEncode() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "With her from—the one: this also has?"
        let encoded = [18, 25, 24, 1, 7, 39, 4, 34, 47, 49, 5]
        XCTAssertEqual(try! tokenizer.encode(tokenizer.tokenize(text)), encoded)
    }
    
    func testBertTokenizerRoundtrip() {
        let config = SpeechConfiguration()
        config.nluVocabularyPath = createVocabularyPath()
        let tokenizer = try! BertTokenizer(config)
        let text = "this also has"
        XCTAssertEqual(try! tokenizer.decodeAndDetokenize(tokenizer.tokenizeAndEncode(text)), text)
    }
    
    func createEncodingsDictionary(_ path: String) throws ->  [String: Int] {
        let vocab = try String(contentsOfFile: path)
        let tokens = vocab.split(separator: "\n").map { String($0) }
        var encodings: [String:Int] = [:]
        for (id, token) in tokens.enumerated() {
            encodings[token] = id
        }
        return encodings
    }
    
    func createVocabularyPath() -> String {
        let path = NSTemporaryDirectory() + "vocab.txt"
        let vocab = """
,
—
.
/
:
?
~
the
of
and
in
to
was
he
is
as
for
on
with
that
it
his
by
at
from
her
##s
she
you
had
an
were
but
be
this
are
not
my
they
one
which
or
have
him
me
first
all
also
their
has
up
who
out
been
when
after
there
into
new
two
s
38
42
74
341
##5
##17
##34
##38
##45
"""
        let file = FileManager.default.createFile(atPath: path, contents: vocab.data(using: .utf8), attributes: .none)
        return path
        
    }
}
