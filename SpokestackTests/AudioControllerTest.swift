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
        let config = SpeechConfiguration()
        let context = SpeechContext()
        controller.configuration = config
        controller.context = context
        let delegate = AudioControllerTestDelegate(config, context: context)
        context.listeners = [delegate]
        context.stageInstances = [delegate]
        let setupFailedExpectation = expectation(description: "testStartStreaming calls AudioControllerTestDelegate as the result of failure method completion")

        // Uninitialized delegates do not cause an exception during startStreaming
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.playAndRecord))
        controller.startStreaming()
        XCTAssertFalse(delegate.didSetupFail)
        
        /// stopStreaming does not cause an exception
        controller.stopStreaming()
        XCTAssertFalse(delegate.didSetupFail)
        
        // Incompatible AVAudioSession category fails
        delegate.reset()
        context.listeners = [delegate]
        context.stageInstances = [delegate]
        controller.context = context
        delegate.asyncExpectation = setupFailedExpectation
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.ambient))
        controller.startStreaming()
        wait(for: [setupFailedExpectation], timeout: 1)
        XCTAssert(delegate.didSetupFail)
        
        /// stopStreaming does not cause an exception
        controller.stopStreaming()
    }
    
    func testProcess() {
        let controller = AudioController.sharedInstance
        let config = SpeechConfiguration()
        let context = SpeechContext()
        controller.configuration = config
        controller.context = context
        let delegate = AudioControllerTestDelegate(config, context: context)
        context.listeners = [delegate]
        context.stageInstances = [delegate]
        let processFrameExpectation = expectation(description: "testStartStreaming calls AudioControllerTestDelegate as the result of processFrame method completion")

        // AudioControllerDelegate processFrame is called
        XCTAssertNoThrow(try AVAudioSession.sharedInstance().setCategory(.record))
        delegate.asyncExpectation = processFrameExpectation
        XCTAssertNotNil(delegate.asyncExpectation)
        controller.startStreaming()
        wait(for: [processFrameExpectation], timeout: 1)
        XCTAssert(delegate.didProcessFrame)
        
        // stopStreaming works
        controller.stopStreaming()
        XCTAssertFalse(delegate.didSetupFail)
    }
}

/// Spy pattern for the system under test.
class AudioControllerTestDelegate: SpeechProcessor, SpeechEventListener {
    var configuration: SpeechConfiguration
    
    var context: SpeechContext
    var didProcessFrame: Bool = false
    var didSetupFail: Bool = false
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var asyncExpectation: XCTestExpectation?
    
    init(_ config: SpeechConfiguration, context: SpeechContext) {
        self.configuration = config
        self.context = context
    }
    
    func reset() {
        didSetupFail = false
        didProcessFrame = false
        asyncExpectation = .none
    }
    
    func startStreaming() {}
    
    func stopStreaming() {}
    
    func didActivate() {}
    
    func didDeactivate() {}
    
    func didRecognize(_ result: SpeechContext) {}
    
    func didTimeout() {}
    
    func didInit() {}
    
    func didStart() {}
    
    func didStop() {}

    func failure(speechError: Error) {
        guard let ae = self.asyncExpectation else {
            XCTFail("AudioControllerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didSetupFail = true
        ae.fulfill()
        self.asyncExpectation = nil
    }
    
    func process(_ frame: Data) -> Void {
        audioProcessingQueue.async {[weak self] in
            // NB the as? cast is necessary for integration testing
            guard let strongSelf = self else {
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
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}
