//
//  SpeechContextTest.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 8/6/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack

class SpeechContextTest: XCTestCase {
    
    func testInit() {
        let config = SpeechConfiguration()
        let c = SpeechContext(config)
        XCTAssertNotNil(c)
    }
    
    func testSetRemoveListener() {
        let config = SpeechConfiguration()
        let c = SpeechContext(config)
        let l1 = SpeechContextTestDelegate()
        let l2 = SpeechContextTestDelegate()
        c.addListener(l1)
        c.addListener(l1)
        c.addListener(l2)
        c.removeListener(l1)
        c.removeListener(l2)
        c.addListener(l1)
        c.addListener(l2)
        c.removeListeners()
        
        let didNotStartExpectation = expectation(description: "didNotStartExpectation never fulfills when testSetRemoveListener calls SpeechContextTestDelegate.start.")
        didNotStartExpectation.isInverted = true
        l1.asyncExpectation = didNotStartExpectation
        // no trace property set means no trace event
        c.dispatch { $0.didStart?() }
        wait(for: [didNotStartExpectation], timeout: 1)
    }
    
    func testDispatch() {
        let config = SpeechConfiguration()
        let c = SpeechContext(config)
        let l = SpeechContextTestDelegate()
        c.addListener(l)

        // init
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testdispatch calls SpeechContextTestDelegate.didInit.")
        l.asyncExpectation = didInitExpectation
        c.dispatch { $0.didInit?() }
        wait(for: [didInitExpectation], timeout: 1)
        XCTAssert(l.didDidInit)
        
        // start
        l.reset()
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testdispatch calls SpeechContextTestDelegate.didStart.")
        l.asyncExpectation = didStartExpectation
        c.dispatch { $0.didStart?() }
        wait(for: [didStartExpectation], timeout: 1)
        XCTAssert(l.didDidStart)

        // stop
        l.reset()
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testdispatch calls SpeechContextTestDelegate.didStop.")
        l.asyncExpectation = didStopExpectation
        c.dispatch { $0.didStop?() }
        wait(for: [didStopExpectation], timeout: 1)
        XCTAssert(l.didDidStop)

        // activate
        l.reset()
        let didActivateExpectation = expectation(description: "didActivateExpectation fulfills when testNotifyListener calls SpeechContextTestDelegate.activate.")
        l.asyncExpectation = didActivateExpectation
        c.dispatch { $0.didActivate?() }
        wait(for: [didActivateExpectation], timeout: 1)
        XCTAssert(l.activated)

        // deactivate
        l.reset()
        let didDeactivateExpectation = expectation(description: "didDeactivateExpectation fulfills when testNotifyListener calls SpeechContextTestDelegate.deactivate.")
        c.addListener(l)
        l.asyncExpectation = didDeactivateExpectation
        c.dispatch { $0.didDeactivate?() }
        wait(for: [didDeactivateExpectation], timeout: 1)
        XCTAssert(l.deactivated)
        
        // recognize
        l.reset()
        let didRecognizeExpectation = expectation(description: "didRecognizeExpectation fulfills when testdispatch calls SpeechContextTestDelegate.recognize.")
        l.asyncExpectation = didRecognizeExpectation
        c.dispatch { $0.didRecognize?(c) }
        wait(for: [didRecognizeExpectation], timeout: 1)
        
        // timeout
        l.reset()
        let didTimeoutExpectation = expectation(description: "didTimeoutExpectation fulfills when testdispatch calls SpeechContextTestDelegate.timeout.")
        l.asyncExpectation = didTimeoutExpectation
        c.dispatch { $0.didTimeout?() }
        wait(for: [didTimeoutExpectation], timeout: 1)

        // error set sends event
        l.reset()
        let didErrorExpectation = expectation(description: "didErrorExpectation fulfills when testdispatch calls SpeechContextTestDelegate.error.")
        l.asyncExpectation = didErrorExpectation
        c.dispatch { $0.failure(error: SpeechPipelineError.illegalState("Life. Don't talk to me about life.")) }
        wait(for: [didErrorExpectation], timeout: 1)
        
        // trace
        let didTraceExpectation = expectation(description: "didTraceExpectation  fulfills when testdispatch calls SpeechContextTestDelegate.trace.")
        l.asyncExpectation = didTraceExpectation
        c.dispatch { $0.didTrace?("hi") }
        wait(for: [didTraceExpectation], timeout: 1)
    }
}

class SpeechContextTestDelegate: SpokestackDelegate {
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didDidInit: Bool = false
    var activated: Bool = false
    var deactivated: Bool = false
    var didDidStart: Bool = false
    var didDidStop: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didDidInit = false
        asyncExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didDeactivate() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.deactivated = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func failure(error: Error) {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didTimeout() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didActivate() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechContextTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.activated = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didInit() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechContextTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidInit = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didStart() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechContextTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidStart = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didStop() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechContextTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidStop = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didTrace(_ trace: String) {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechContextTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
}
