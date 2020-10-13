//
//  SharedTestMocks.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 2/25/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import TensorFlowLite

internal enum NLUModel {
    static let info = (name: "mock_nlu", extension: "tflite")
    static let input = [Int32](Array(repeating: 0, count: 128)).withUnsafeBufferPointer(Data.init)
    static let validIndex = 0
    static let shape: TensorShape = [2]
    static let inputData = [Int32]([Int32(1), Int32(3)]).withUnsafeBufferPointer(Data.init)
    static let outputData = [Int32]([0, 0, 0, 0, 0, 0, 0, 0]).withUnsafeBufferPointer(Data.init)
    static var path: String = {
        let bundle = Bundle(for: NLUTensorflowTest.self)
        let p = bundle.path(forResource: info.name, ofType: info.extension)
        return p!
    }()
}

internal struct SharedTestMocks {
    static func createEncodingsDictionary(_ path: String) throws ->  [String: Int] {
        let vocab = try String(contentsOfFile: path)
        let tokens = vocab.split(separator: "\n").map { String($0) }
        var encodings: [String:Int] = [:]
        for (id, token) in tokens.enumerated() {
            encodings[token] = id
        }
        return encodings
    }
    
    static func createModelMetadataPath() -> String {
        let path = NSTemporaryDirectory() + "nlu.json"
        let model = #"""
                {
                  "intents": [{"name": "","slots": []}],
                  "tags": ["o"]
                }
        """#
        let _ = FileManager.default.createFile(atPath: path, contents: model.data(using: .utf8), attributes: .none)
        return path
    }
    
    static func createVocabularyPath() -> String {
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
    twenty
    38
    42
    74
    341
    ##5
    ##17
    ##34
    ##38
    ##46
    million
    [UNK]
    alesund
    """
        let _ = FileManager.default.createFile(atPath: path, contents: vocab.data(using: .utf8), attributes: .none)
        return path
        
    }
}
