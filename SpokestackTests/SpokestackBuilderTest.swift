//
//  SpokestackBuilderTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/29/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack

class SpokestackBuilderTest: XCTestCase {
    
    func testBuild() {
        let delegate = SpokestackTestDelegate()
        
        // nothing provided still builds
        let s1 = try! SpokestackBuilder()
            .build()
        XCTAssertNotNil(s1)
        XCTAssertNotNil(s1.nlu)
        XCTAssertNotNil(s1.tts)
        XCTAssertNotNil(s1.pipeline)
        
        // build with delegate, profile, and properties
        let queue = DispatchQueue.main
        let wakeActiveMin = 10000
        let level = Trace.Level.PERF
        let s2 = try! SpokestackBuilder()
            .addDelegate(delegate)
            .usePipelineProfile(.vadTriggerSpokestackSpeech)
            .setDelegateDispatchQueue(queue)
            .setProperty("wakeActiveMin", wakeActiveMin.description)
            .setProperty("tracing", level)
            .build()
        XCTAssert([WebRTCVAD.self, VADTrigger.self, SpokestackSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
        XCTAssert(queue === s2.configuration.delegateDispatchQueue)
        XCTAssertEqual(wakeActiveMin, s2.configuration.wakeActiveMin)
        XCTAssertEqual(level, s2.configuration.tracing)
        
        // build with invalid tracing level
        let s3 = try! SpokestackBuilder()
            .setProperty("tracing", -1)
            .build()
        XCTAssertEqual(s3.configuration.tracing, .NONE)
    }
}

class SpokestackTestDelegate: SpokestackDelegate {
    
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didDidInit: Bool = false
    var activated: Bool = false
    var didDidStart: Bool = false
    var didDidStop: Bool = false
    var asyncExpectation: XCTestExpectation?
    var deactivateExpectation: XCTestExpectation?
    
    func reset() {
        didDidInit = false
        asyncExpectation = .none
        deactivateExpectation = .none
    }
    
    func failure(error: Error) { }
}
