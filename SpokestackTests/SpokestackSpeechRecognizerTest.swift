//
//  SpokestackSpeechRecognizerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 7/16/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack

@available(iOS 13.0, *)
class SpokestackSpeechRecognizerTest: XCTestCase {
    func testStartStopStreaming() {
        // setup
        let configuration = SpeechConfiguration()
        let context = SpeechContext(configuration)
        let delegate = SpokestackSpeechRecognizerTestDelegate()
        context.addListener(delegate)
        let ssr = SpokestackSpeechRecognizer(configuration, context: context)
        context.isActive = true
        context.isSpeech = true
        
        // start & stop
        ssr.startStreaming()
        XCTAssert(context.isActive)
        XCTAssertFalse(delegate.didError)
        ssr.stopStreaming()
        XCTAssertFalse(delegate.didError)
    }
    
    func testProcess() {
        // setup
        let didFailExpectation = expectation(description: "default configuration should not result in a failed request that calls SpokestackSpeechRecognizerTestDelegate.failure")
        didFailExpectation.isInverted = true
        didFailExpectation.assertForOverFulfill = false
        let configuration = SpeechConfiguration()
        let context = SpeechContext(configuration)
        let delegate = SpokestackSpeechRecognizerTestDelegate()
        context.addListener(delegate)
        delegate.asyncExpectation = didFailExpectation
        let ssr = SpokestackSpeechRecognizer(configuration, context: context)
        context.isSpeech = true
        ssr.startStreaming()
        
        // process
        // asr does not set active
        ssr.process(Frame.silence(frameWidth: 10, sampleRate: 16000))
        XCTAssertFalse(context.isActive)
        XCTAssertFalse(delegate.didError)
        // process a voice frame successfully
        context.isActive = true
        ssr.process(Frame.voice(frameWidth: 10, sampleRate: 16000))
        wait(for: [didFailExpectation], timeout: 2)
        XCTAssert(context.isActive)
        XCTAssertFalse(delegate.didError)
        // deactivate
        context.isActive = false
        context.isSpeech = false
        ssr.process(Frame.voice(frameWidth: 10, sampleRate: 16000))
    }

    func testFailure() {
        // setup
        let badConfiguration = SpeechConfiguration()
        let delegate = SpokestackSpeechRecognizerTestDelegate()
        let context = SpeechContext(badConfiguration)
        context.addListener(delegate)

        // bad key id
        let didFailConfigExpectation = expectation(description: "bad config results in a failed request that calls SpokestackSpeechRecognizerTestDelegate.failure")
        didFailConfigExpectation.assertForOverFulfill = false
        delegate.asyncExpectation = didFailConfigExpectation
        badConfiguration.apiId = "BADBADNOTGOOD"
        context.isSpeech = true
        context.isActive = true
        let ssr = SpokestackSpeechRecognizer(badConfiguration, context: context)
        ssr.startStreaming()
        ssr.process(Frame.voice(frameWidth: 10, sampleRate: 16000))
        wait(for: [didFailConfigExpectation], timeout: 1)
        XCTAssert(delegate.didError)
        // can't guarantee order of server responses to an unauthorized request, so have to check for both
        XCTAssert((context.error!.localizedDescription == "Spokestack ASR responded with an error: unauthorized") || (context.error!.localizedDescription == "Spokestack ASR responded with an error: request_failed"))
    }
}

class SpokestackSpeechRecognizerTestDelegate: SpeechEventListener {
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didError: Bool = false
    var didDidTimeout: Bool = false
    var deactivated: Bool = false
    var didRecognize: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        self.didError = false
        self.didDidTimeout = false
        self.deactivated = false
        self.didRecognize = false
        self.didRecognize = false
        asyncExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {
        print(result)
        self.didRecognize = true
    }
    
    func failure(speechError: Error) {
        print(speechError)
        guard let _ = asyncExpectation else {
            XCTFail("SpokestackSpeechRecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didError = true
        self.asyncExpectation?.fulfill()
    }
    
    func didTimeout() {
        self.didDidTimeout = true
    }
    
    func didActivate() {}

    func didDeactivate() {
        self.deactivated = true
    }
    
    func didStop() {}
    
    func didStart() {}
    
    func didInit() {}
    
    func setupFailed(_ error: String) {}
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}
