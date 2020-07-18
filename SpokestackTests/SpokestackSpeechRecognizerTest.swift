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
        /// setup
        let configuration = SpeechConfiguration()
        let context = SpeechContext()
        let delegate = SpokestackSpeechRecognizerTestDelegate()
        context.listeners = [delegate]
        let ssr = SpokestackSpeechRecognizer(configuration, context: context)
        context.isActive = true
        context.isSpeech = true
        
        // start & stop
        ssr.startStreaming()
        sleep(1)
        XCTAssert(context.isActive)
        XCTAssertFalse(delegate.didError)
        ssr.stopStreaming()
        XCTAssertFalse(context.isActive)
        XCTAssertFalse(delegate.didError)
    }
    
    func testProcess() {
        /// setup
        let configuration = SpeechConfiguration()
        let context = SpeechContext()
        let delegate = SpokestackSpeechRecognizerTestDelegate()
        context.listeners = [delegate]
        let ssr = SpokestackSpeechRecognizer(configuration, context: context)
        context.stageInstances = [ssr]
        context.isSpeech = true
        ssr.startStreaming()
        
        // process
        // asr does not set active
        ssr.process(Frame.silence(frameWidth: 10, sampleRate: 16000))
        XCTAssertFalse(context.isActive)
        XCTAssertFalse(delegate.didError)
        ssr.process(Frame.voice(frameWidth: 10, sampleRate: 16000))
        sleep(1)
        XCTAssertFalse(context.isActive)
        XCTAssertFalse(delegate.didError)
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
