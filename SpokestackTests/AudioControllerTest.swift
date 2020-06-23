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
        let context = SpeechContext()
        let setupFailedExpectation = expectation(description: "testStartStreaming calls AudioControllerTestDelegate as the result of setupFailed method completion")
        let processFrameExpectation = expectation(description: "testStartStreaming calls AudioControllerTestDelegate as the result of processFrame method completion")

        // Uninititalized delegates do not cause an exception during startStreaming
        XCTAssertNoThrow(controller.startStreaming(context: context))
        /// stopStreaming does not cause an exception
        XCTAssertNoThrow(controller.stopStreaming(context: context))
        
        // Initialized PipelineDelegate is called during startStreaming
        controller.pipelineDelegate = delegate
        delegate.asyncExpectation = setupFailedExpectation
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.ambient))
        XCTAssertNoThrow(controller.startStreaming(context: context))
        wait(for: [setupFailedExpectation], timeout: 1)
        XCTAssert(delegate.didSetupFailed)
        /// stopStreaming does not cause an exception
        XCTAssertNoThrow(controller.stopStreaming(context: context))

        delegate.reset()

        // AudioControllerDelegate processFrame is called
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.record))
        delegate.asyncExpectation = processFrameExpectation
        XCTAssertNotNil(delegate.asyncExpectation)
        XCTAssertNoThrow(controller.startStreaming(context: context))
        wait(for: [processFrameExpectation], timeout: 2)
        XCTAssert(delegate.didProcessFrame)
        // stopStreaming does not cause an exception
        XCTAssertNoThrow(controller.stopStreaming(context: context))
    }
}

/// Spy pattern for the system under test.
class AudioControllerTestDelegate: AudioControllerDelegate, PipelineDelegate {
    
    var didProcessFrame: Bool = false
    var didSetupFailed: Bool = false
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didSetupFailed = false
        asyncExpectation = .none
    }
    
    func process(_ frame: Data) -> Void {
        audioProcessingQueue.async {[weak self] in
            // NB the as? cast is necessary for integration testing
            guard let strongSelf = self as? AudioControllerTestDelegate else {
                XCTFail("AudioControllerTestDelegate was not setup correctly. Missing strong self reference")
                return
            }
            guard let ae = strongSelf.asyncExpectation else {
                XCTFail("AudioControllerTestDelegate was not setup correctly. Missing XCTExpectation reference")
                return
            }
            strongSelf.didProcessFrame = true
            ae.fulfill()
            strongSelf.asyncExpectation = nil
        }
    }
    
    func didInit() {
        
    }
    
    func didStart() {
        
    }
    
    func didStop() {
        
    }
    
    func setupFailed(_ error: String) {
        guard let ae = self.asyncExpectation else {
            XCTFail("AudioControllerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didSetupFailed = true
        ae.fulfill()
        self.asyncExpectation = nil
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    
}
