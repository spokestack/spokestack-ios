//
//  AppleWakewordRecognizerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/18/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack
import AVFoundation

class AppleWakewordRecognizerTest: XCTestCase {
    
    // init & deinit & startStreaming & stopStreaming
    func testStartStreaming() {
        // setup
        let configuration = SpeechConfiguration()
        let context = SpeechContext(configuration)
        let awr = AppleWakewordRecognizer(configuration, context: context)
        awr.context = context

        // no delegate & no configuration
        awr.startStreaming()
        XCTAssertFalse(context.isActive)
        awr.stopStreaming()
        XCTAssertFalse(context.isActive)
    }
    
    // process
    func testProcess() {
        // setup
        let configuration = SpeechConfiguration()
        let context = SpeechContext(configuration)
        let awr = AppleWakewordRecognizer(configuration, context: context)
        awr.context = context
        let delegate = AppleWakewordRecognizerTestDelegate()
        context.addListener(delegate)
        awr.context = context
        
        // activate
        context.isActive = false
        context.isSpeech = true
        awr.startStreaming()
        XCTAssertFalse(delegate.didError)
        awr.process(Frame.silence(frameWidth: 10, sampleRate: 8000))
        XCTAssertFalse(context.isActive)

        // activate while asr is running is a noop
        context.isActive = true
        awr.process(Frame.voice(frameWidth: 10, sampleRate: 8000))
        XCTAssert(context.isActive)

        XCTAssertFalse(delegate.didError)

        // stopStreaming does not change active status (that's the job of SpeechPipeline)
        awr.stopStreaming()
        XCTAssert(context.isActive)
        XCTAssertFalse(delegate.didError)
    }
}

class AppleWakewordRecognizerTestDelegate: SpeechEventListener {
    
    // Spy pattern for the system under test.
    // asyncExpectation lets the caller's test know when the delegate has been called.
    var didError: Bool = false
    var deactivated: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        self.didError = false
        self.deactivated = false
        asyncExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {}
    
    func failure(speechError: Error) {
        print(speechError)
        guard let _ = asyncExpectation else {
            XCTFail("AppleWakewordRecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didError = true
        self.asyncExpectation?.fulfill()
    }
    
    func didTimeout() {}
    
    func didActivate() {}
    
    func didDeactivate() {
        self.deactivated = true
    }
    
    func didInit() {}
    
    func didStart() {}
    
    func didStop() {}
    
    func setupFailed(_ error: String) {}
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}
