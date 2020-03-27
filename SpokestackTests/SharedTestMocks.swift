//
//  SharedTestMocks.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 2/25/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

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
    ##45
    million
    [UNK]
    alesund
    """
        let _ = FileManager.default.createFile(atPath: path, contents: vocab.data(using: .utf8), attributes: .none)
        return path
        
    }
}
