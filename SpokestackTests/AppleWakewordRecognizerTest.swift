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
    
    /// init & deinit & startStreaming & stopStreaming
    func testStartStreaming() {
        /// setup
        let awr = AppleWakewordRecognizer.sharedInstance
        let context = SpeechContext()
        let delegate = AppleWakewordRecognizerTestDelegate()
        
        /// no delegate & no configuration
        XCTAssertNoThrow(awr.startStreaming(context: context))
        
        /// strong delegate & configuration
        awr.configuration = SpeechConfiguration()
        awr.delegate = delegate
        XCTAssertNoThrow(awr.startStreaming(context: context))
        
        /// stopStreaming
        XCTAssertNoThrow(awr.stopStreaming(context: context))
    }
    
    /// process
    func testProcess() {
        // TODO
    }
    
    /// activate & deactivate
    func testActivatetDeactivate() {
        /// setup
        let awr = AppleWakewordRecognizer.sharedInstance
        let context = SpeechContext()
        let delegate = AppleWakewordRecognizerTestDelegate()
        awr.delegate = delegate
        awr.configuration = SpeechConfiguration()
        awr.context = context
        
        /// activate without startStreaming does not trip AudioEngine assertion
        awr.activate(frame: Frame.silence(frameWidth: 10, sampleRate: 8000))
        
        /// activate while asr is running is a noop
        context.isActive = true
        awr.activate(frame: Frame.silence(frameWidth: 10, sampleRate: 8000))
        
        /// activate
        context.isActive = false
        awr.startStreaming(context: context)
        XCTAssert(context.isStarted)
        // awr.activate(frame: Frame.silence(frameWidth: 10, sampleRate: 8000))
        /* TODO: fails the delegate assertion in the resultHandler callback because the callback occurs after the test has completed and thus the testdelegate has been destroyed. Need to refactor SpeechProcessor so that an expectation can be fulfilled for this type of async testing. */

        /// deactivate while asr is running is a noop
        context.isActive = true
        awr.context = context
        awr.deactivate()
        XCTAssert(context.isStarted)

        /// deactivate
        awr.stopStreaming(context: context)
        awr.deactivate()
        XCTAssert(!context.isStarted)
    }
}

class AppleWakewordRecognizerTestDelegate: PipelineDelegate, SpeechEventListener {
    
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didError: Bool = false
    var didDeactivate: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        self.didError = false
        self.didDeactivate = false
        asyncExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {}
    
    func didError(_ error: Error) {
        print(error)
        guard let _ = asyncExpectation else {
            XCTFail("AppleWakewordRecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didError = true
        self.asyncExpectation?.fulfill()
    }
    
    func didTimeout() {}
    
    func activate() {}
    
    func deactivate() {
        self.didDeactivate = true
    }
    
    func didInit() {}
    
    func didStart() {}
    
    func didStop() {}
    
    func setupFailed(_ error: String) {}
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}
