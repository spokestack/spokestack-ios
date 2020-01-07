//
//  WebRTCVADTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/3/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import XCTest
import Spokestack

class WebRTCVADTest: XCTestCase {
    
    func testCreate() {
        let vad = WebRTCVAD()

        // valid config
        XCTAssertNoThrow(try vad.create(mode: VADMode.HighlyPermissive, delegate: WebRTCVADTestDelegate(), frameWidth: 10, sampleRate: 8000))
        // TODO: HighlyRestrictive throws…
        // XCTAssertNoThrow(try vad.create(mode: VADMode.HighlyRestrictive, delegate: WebRTCVADTestDelegate(), frameWidth: 10, sampleRate: 16000))
        XCTAssertNoThrow(try vad.create(mode: VADMode.Permissive, delegate: WebRTCVADTestDelegate(), frameWidth: 20, sampleRate: 32000))
        XCTAssertNoThrow(try vad.create(mode: VADMode.Restrictive, delegate: WebRTCVADTestDelegate(), frameWidth: 30, sampleRate: 48000))

        // invalid config
        var thrownError: Error?
        XCTAssertThrowsError(try vad.create(mode: VADMode.HighlyPermissive, delegate: WebRTCVADTestDelegate(), frameWidth: 10, sampleRate: 44100)) { thrownError = $0 }
        XCTAssert(thrownError is VADError, "unexpected error type \(type(of: thrownError)) during read()")
        XCTAssertEqual(thrownError as? VADError, VADError.invalidConfiguration("Invalid sampleRate of 44100"))
        thrownError = .none
        XCTAssertThrowsError(try vad.create(mode: VADMode.HighlyPermissive, delegate: WebRTCVADTestDelegate(), frameWidth: 40, sampleRate: 32000)) { thrownError = $0 }
        XCTAssert(thrownError is VADError, "unexpected error type \(type(of: thrownError)) during read()")
        XCTAssertEqual(thrownError as? VADError, VADError.invalidConfiguration("Invalid frameWidth of 40"))
    }
    
    /// Since WebRTCVAD uses Data for frames, there's no danger of null pointers, so our tests are simple =)
    func testProcess() {
        /// setup
        let delegate = WebRTCVADTestDelegate()
        let deactivateExpectation = expectation(description: "testProcess calls WebRTCVADTestDelegate as the result of deactivate method completion")
        let activateExpectation = expectation(description: "testProcess calls WebRTCVADTestDelegate as the result of activate method completion")
        let vad = WebRTCVAD()
        XCTAssertNoThrow(try vad.create(mode: VADMode.HighlyPermissive, delegate: delegate, frameWidth: 10, sampleRate: 8000))
        
        /// speech -> no speech
        delegate.asyncExpectation = deactivateExpectation
        XCTAssertNoThrow(try vad.process(frame: Frame.silence(frameWidth: 10, sampleRate: 8000), isSpeech: true))
        wait(for: [delegate.asyncExpectation!], timeout: 1)
            XCTAssert(delegate.didDeactivate, "deactivate should be called because silence + isSpeech: true")
        delegate.reset()
        
        /// no speech
        for _ in 0...9 {
            XCTAssertNoThrow(try vad.process(frame: Frame.silence(frameWidth: 10, sampleRate: 8000), isSpeech: false))
        }
        XCTAssert(!delegate.didDeactivate, "deactivate should not be called because silence + isSpeech: false")
        delegate.reset()

        
        /// no speech -> speech
        delegate.asyncExpectation = activateExpectation
        XCTAssertNoThrow(try vad.process(frame: Frame.voice(frameWidth: 10, sampleRate: 8000), isSpeech: false))
        wait(for: [delegate.asyncExpectation!], timeout: 1)
        XCTAssert(delegate.didActivate, "activate should be called because voice + isSpeech: false")
        delegate.reset()

        /// speech
        for _ in 0...9 {
            XCTAssertNoThrow(try vad.process(frame: Frame.voice(frameWidth: 10, sampleRate: 8000), isSpeech: true))
        }
        XCTAssert(!delegate.didActivate, "activate should not be called because voice + isSpeech: true")
    }
}

class WebRTCVADTestDelegate: VADDelegate, PipelineDelegate {
    
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didActivate: Bool = false
    var didDeactivate: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didActivate = false
        didDeactivate = false
        asyncExpectation = .none
    }
    
    func didInit() {
        Trace.trace(Trace.Level.DEBUG, configLevel: Trace.Level.DEBUG, message: "didInit", delegate: self, caller: self)
    }
    
    func didStart() {
        Trace.trace(Trace.Level.DEBUG, configLevel: Trace.Level.DEBUG, message: "didStart", delegate: self, caller: self)
    }
    
    func didStop() {
        Trace.trace(Trace.Level.DEBUG, configLevel: Trace.Level.DEBUG, message: "didStop", delegate: self, caller: self)
    }
    
    func setupFailed(_ error: String) {
        Trace.trace(Trace.Level.DEBUG, configLevel: Trace.Level.DEBUG, message: "setupFailed", delegate: self, caller: self)
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    func activate(frame: Data) {
        guard let _ = asyncExpectation else {
            XCTFail("WebRTCVADTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didActivate = true
        Trace.trace(Trace.Level.DEBUG, configLevel: Trace.Level.DEBUG, message: "activate", delegate: self, caller: self)
        asyncExpectation?.fulfill()
    }
    
    func deactivate() {
        guard let _ = asyncExpectation else {
            XCTFail("WebRTCVADTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDeactivate = true
        Trace.trace(Trace.Level.DEBUG, configLevel: Trace.Level.DEBUG, message: "deactivate", delegate: self, caller: self)
        asyncExpectation?.fulfill()
    }
}
