//
//  AudioControllerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/6/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack
import AVFoundation

class AudioControllerTest: XCTestCase {
    func testStreaming() {
        let controller = AudioController.sharedInstance
        let delegate = AudioControllerTestDelegate()
        let setupFailedExpectation = expectation(description: "testStartStreaming calls AudioControllerTestDelegate as the result of setupFailed method completion")
        let processFrameExpectation = expectation(description: "testStartStreaming calls AudioControllerTestDelegate as the result of processFrame method completion")

        /// Uninititalized delegates do not cause an exception during startStreaming
        XCTAssertNoThrow(controller.startStreaming(context: SpeechContext()))
        
        /// Initialized PipelineDelegate is called during startStreaming
        controller.pipelineDelegate = delegate
        controller.delegate = delegate
        delegate.asyncExpectation = setupFailedExpectation
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.ambient))
        XCTAssertNoThrow(controller.startStreaming(context: SpeechContext()))
        wait(for: [setupFailedExpectation], timeout: 1)
        XCTAssert(delegate.didSetupFailed)
        delegate.reset()
        
        /// stopStreaming does not cause an exception
        XCTAssertNoThrow(controller.stopStreaming(context: SpeechContext()))
        
        /// AudioControllerDelegate processFrame is called
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.record))
        delegate.asyncExpectation = processFrameExpectation
        XCTAssertNoThrow(controller.startStreaming(context: SpeechContext()))
        wait(for: [processFrameExpectation], timeout: 2)
        XCTAssert(delegate.didProcessFrame)
    }
}

class AudioControllerTestDelegate: AudioControllerDelegate, PipelineDelegate {
    
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didProcessFrame: Bool = false
    var didSetupFailed: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didSetupFailed = false
        asyncExpectation = .none
    }
    
    func process(_ frame: Data) {
        guard let _ = asyncExpectation else {
            XCTFail("AudioControllerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didProcessFrame = true
        self.asyncExpectation?.fulfill()
    }
    
    func didInit() {
        
    }
    
    func didStart() {
        
    }
    
    func didStop() {
        
    }
    
    func setupFailed(_ error: String) {
        guard let _ = asyncExpectation else {
            XCTFail("AudioControllerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didSetupFailed = true
        self.asyncExpectation?.fulfill()
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    
}
