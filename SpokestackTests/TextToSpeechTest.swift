//
//  TTSManagerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 11/15/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack

class TextToSpeechTest: XCTestCase {
    
    /// MARK: Synthesize
    func testSynthesize() {
        let delegate = TestTextToSpeechDelegate()
        let input = TextToSpeechInput()

        // bad config results in a failed request that calls failure
        let badConfig = SpeechConfiguration()
        let didFailConfigExpectation = expectation(description: "bad config results in a failed request that calls TestTTSGenerationDelegate.failure")
        badConfig.authorization = "BADBADNOTGOOD"
        let badTTS = TextToSpeech(delegate, configuration: badConfig)
        delegate.asyncExpectation = didFailConfigExpectation
        badTTS.synthesize(input)
        wait(for: [didFailConfigExpectation], timeout: 5)
        XCTAssert(delegate.didFail)
        XCTAssertFalse(delegate.didSucceed)
        
        let config = SpeechConfiguration()
        let tts = TextToSpeech(delegate, configuration: config)
        
        // successful request calls success
        delegate.reset()
        let didSucceedExpectation = expectation(description: "successful request calls TestTTSGenerationDelegate.success")
        delegate.asyncExpectation = didSucceedExpectation
        tts.synthesize(input)
        wait(for: [didSucceedExpectation], timeout: 5)
        XCTAssert(delegate.didSucceed)
        XCTAssertFalse(delegate.didFail)
        
        // bad input results in a failed request that calls failure
        delegate.reset()
        let didFailInputExpectation = expectation(description: "bad input results in a failed request that calls TestTTSGenerationDelegate.failure")
        let badInput = TextToSpeechInput()
        badInput.voice = "marvin"
        delegate.asyncExpectation = didFailInputExpectation
        tts.synthesize(badInput)
        wait(for: [didFailInputExpectation], timeout: 5)
        XCTAssert(delegate.didFail)
        XCTAssertFalse(delegate.didSucceed)
    }
}

class TestTextToSpeechDelegate: TextToSpeechDelegate {
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didSucceed: Bool = false
    var didFail: Bool = false
    var didDidStart: Bool = false
    var didDidStop: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didSucceed = false
        didFail = false
        asyncExpectation = .none
    }
    
    func success(url: URL) {
        asyncExpectation?.fulfill()
        didSucceed = true
    }
    
    func failure(error: Error) {
        asyncExpectation?.fulfill()
        didFail = true
    }
    
    func didTrace(_ trace: String) -> Void {
        print(trace)
    }
}
