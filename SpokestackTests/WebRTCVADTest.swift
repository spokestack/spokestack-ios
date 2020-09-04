//
//  WebRTCVADTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/3/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import XCTest
import Spokestack

class WebRTCVADTest: XCTestCase {
    
    func testCreate() {
        // setup
        let config = SpeechConfiguration()
        let context = SpeechContext(config)
        let failureSampleRateExpectation = expectation(description: "testCreate calls WebRTCVADTestDelegate when WebRTCVAD initialization fails due to invalid sampleRate")
        let failureFrameWidthExpectation = expectation(description: "testCreate calls WebRTCVADTestDelegate when WebRTCVAD initialization fails due to invalid frameWidth")
        let delegate = WebRTCVADTestDelegate()
        delegate.context = context
        delegate.config = config
        context.addListener(delegate)
        delegate.failureExpectation = failureSampleRateExpectation
        
        // valid configs
        
        config.vadMode = .HighlyPermissive
        config.frameWidth = 10
        config.sampleRate = 8000
        let _ = WebRTCVAD(config, context: context)
        XCTAssertFalse(delegate.failed)
        
        config.vadMode = .Permissive
        config.frameWidth = 20
        config.sampleRate = 32000
        let _ = WebRTCVAD(config, context: context)
        XCTAssertFalse(delegate.failed)
        
        config.vadMode = .Restrictive
        config.frameWidth = 30
        config.sampleRate = 48000
        let _ = WebRTCVAD(config, context: context)
        XCTAssertFalse(delegate.failed)
        
        /// - TODO: .HighlyRestrictive is a valid config but WebRTC asserts is invalid
        //        config.vadMode = .HighlyRestrictive
        //        config.frameWidth = 10
        //        config.sampleRate = 16000
        //        let _ = WebRTCVAD(config, context: context)
        //        XCTAssertFalse(delegate.failed)
        
        // invalid config
        
        config.vadMode = .HighlyPermissive
        config.frameWidth = 10
        config.sampleRate = 44100
        let _ = WebRTCVAD(config, context: context)
        wait(for: [delegate.failureExpectation!], timeout: 1)
        XCTAssert(delegate.failed, "WebRTCVAD initialization should fail")
        XCTAssert(delegate.error is VADError, "unexpected error type \(type(of: delegate.error)) during read()")
        XCTAssertEqual(delegate.error as? VADError, VADError.invalidConfiguration("Invalid sampleRate of 44100"))
        
        delegate.reset()
        delegate.failureExpectation = failureFrameWidthExpectation
        config.vadMode = .HighlyPermissive
        config.frameWidth = 40
        config.sampleRate = 32000
        let _ = WebRTCVAD(config, context: context)
        wait(for: [delegate.failureExpectation!], timeout: 1)
        XCTAssert(delegate.failed, "WebRTCVAD initialization should fail")
        XCTAssert(delegate.error is VADError, "unexpected error type \(type(of: delegate.error)) during read()")
        XCTAssertEqual(delegate.error as? VADError, VADError.invalidConfiguration("Invalid frameWidth of 40"))
    }
    
    /// Since WebRTCVAD uses Data for frames, there's no danger of null pointers, so our tests are simple =)
    func testProcess() {
        /// setup
        let delegate = WebRTCVADTestDelegate()
        let config = SpeechConfiguration()
        let context = SpeechContext(config)
        delegate.context = context
        delegate.config = config
        context.addListener(delegate)
        config.vadMode = .Permissive
        config.frameWidth = 10
        config.sampleRate = 8000
        config.wakeActiveMin = 1
        config.wakeActiveMax = 3
        let vad = WebRTCVAD(config, context: context)
        
        /// speech -> no speech
        context.isSpeech = true
        vad.process(Frame.silence(frameWidth: config.frameWidth, sampleRate: config.sampleRate))
        vad.process(Frame.silence(frameWidth: config.frameWidth, sampleRate: config.sampleRate))
        XCTAssertFalse(delegate.failed, "Process should not cause a failure")
        XCTAssertFalse(context.isSpeech, "isSpeech should be false because silence")
        
        /// no speech
        delegate.reset()
        context.isSpeech = false
        for _ in 0...9 {
            vad.process(Frame.silence(frameWidth: 10, sampleRate: 8000))
        }
        XCTAssertFalse(delegate.failed, "Process should not cause a failure")
        XCTAssertFalse(context.isSpeech, "isSpeech should be false because silence")
        delegate.reset()
        
        /// no speech -> speech
        context.isSpeech = false
        vad.process(Frame.voice(frameWidth: 10, sampleRate: 8000))
        vad.process(Frame.voice(frameWidth: 10, sampleRate: 8000))
        XCTAssertFalse(delegate.failed, "Process should not cause a failure")
        XCTAssert(context.isSpeech, "isSpeech should be true because voice + isSpeech: false")
        
        /// speech
        delegate.reset()
        context.isSpeech = true
        for _ in 0...(config.wakeActiveMax-1) {
            vad.process(Frame.voice(frameWidth: 10, sampleRate: 8000))
        }
        XCTAssertFalse(delegate.failed, "Process should not cause a failure")
        XCTAssert(context.isSpeech, "isSpeech should be true because voice: false")
    }
}

class WebRTCVADTestDelegate: SpeechEventListener {
    
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var initialized: Bool = false
    var failed: Bool = false
    var failureExpectation: XCTestExpectation?
    var error: Error?
    var config = SpeechConfiguration()
    var context: SpeechContext
    
    init() {
        config.tracing = .DEBUG
        self.context = SpeechContext(config)
    }
    
    func reset() {
        initialized = false
        failed = false
        error = .none
    }
    
    func didInit() {
        self.initialized = true
    }
    
    func didStart() {
        Trace.trace(.DEBUG, message: "didStart", config: config, context: context, caller: self)
    }
    
    func didStop() {
        Trace.trace(.DEBUG, message: "didStop", config: config, context: context, caller: self)
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    func didActivate() {
        Trace.trace(.DEBUG, message: "didActivate", config: config, context: context, caller: self)
    }
    
    func didDeactivate() {
        Trace.trace(.DEBUG, message: "didDeactivate", config: config, context: context, caller: self)
    }
    
    func didRecognize(_ result: SpeechContext) {
        Trace.trace(.DEBUG, message: "didRecognize", config: config, context: context, caller: self)
    }
    
    func failure(speechError: Error) {
        self.failed = true
        self.error = speechError
        Trace.trace(.DEBUG, message: "failure", config: config, context: context, caller: self)
        self.failureExpectation?.fulfill()
    }
    
    func didTimeout() {
        Trace.trace(.DEBUG, message: "didTimeout", config: config, context: context, caller: self)
    }
    
    func activate(frame: Data) {
        Trace.trace(.DEBUG, message: "activate", config: config, context: context, caller: self)
    }
    
    func deactivate() {
        Trace.trace(.DEBUG, message: "deactivate", config: config, context: context, caller: self)
    }
}
