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
    func testTokenize() {
        let config = SpeechConfiguration()
        config.vocabularyPath = createVocabularyPath()
        let tokenizer = Tokenizer(config)
        let text = "With her from－the one: this also has?"
        let tokens = ["with", "her", "from", "the", "one", "this", "also", "has"]
        XCTAssertEqual(tokenizer.tokenize(text), tokens)
    }
    
    func testTokenizeDetokenizeRoundtrip() {
        let config = SpeechConfiguration()
        config.vocabularyPath = createVocabularyPath()
        let tokenizer = Tokenizer(config)
        let text = "this also has"
        XCTAssertEqual(try tokenizer.detokenize(tokenizer.tokenize(text)), text)
    }
    
    func testEncode() {
        let config = SpeechConfiguration()
        config.vocabularyPath = createVocabularyPath()
        let tokenizer = Tokenizer(config)
        let text = "With her from－the one: this also has?"
        let encoded = [18, 25, 24, 7, 39, 34, 47, 49]
        XCTAssertEqual(try! tokenizer.encode(tokenizer.tokenize(text)), encoded)
    }
    
    func testRoundtrip() {
        let config = SpeechConfiguration()
        config.vocabularyPath = createVocabularyPath()
        let tokenizer = Tokenizer(config)
        let text = "this also has"
        XCTAssertEqual(try! tokenizer.decodeAndDetokenize(tokenizer.tokenizeAndEncode(text)), text)
    }
    
    func createVocabularyPath() -> String {
        let path = NSTemporaryDirectory() + "vocab.txt"
        let vocab = """
，
－
．
／
：
？
～
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
"""
        let file = FileManager.default.createFile(atPath: path, contents: vocab.data(using: .utf8), attributes: .none)
        return path
        
    }
}
