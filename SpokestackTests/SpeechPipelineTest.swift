//
//  SpeechPipelineTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/6/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack

class SpeechPipelineTest: XCTestCase {
    
    /// convenience init
    func testConvenienceInit() {
        let delegate = SpeechPipelineTestDelegate()
        let didInitExpectation = expectation(description: "testInit calls SpeechPipelineTestDelegate as the result of didInit method completion")
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()

        // successful init calls didInit
        _ = SpeechPipeline(configuration: config, listeners: [delegate])
        wait(for: [didInitExpectation], timeout: 1)
        XCTAssert(delegate.didDidInit)
    }
    
    /// init
    func testInit() {
        let delegate = SpeechPipelineTestDelegate()
        let didInitExpectation = expectation(description: "testInit calls SpeechPipelineTestDelegate as the result of didInit method completion")
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()
        let context = SpeechContext()
        config.fftHopLength = 30

        // successful init calls didInit
        let tp = TestProcessor(true, config: config, context: context)
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        p.context.stageInstances = [tp]
        wait(for: [didInitExpectation], timeout: 1)
        XCTAssert(delegate.didDidInit)
        
        // successful init sets config property
        XCTAssert(p.configuration.fftHopLength == 30)
    }
    
    /// activate & deactivate
    func testActivateDeactivate() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testActivateDeactivate calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let delegate = SpeechPipelineTestDelegate()
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()
        let context = SpeechContext()

        // init the pipeline
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        _ = TestProcessor(true, config: config, context: context)
        wait(for: [didInitExpectation], timeout: 1)
        
        // activate and deactivate the pipeline
        p.activate()
        XCTAssert(p.context.isActive)
        p.deactivate()
        XCTAssert(!p.context.isActive)
    }
    
    /// start & stop
    func testStartStop() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()
        let context = SpeechContext()

        // init the pipeline
        delegate.asyncExpectation = didInitExpectation
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        let tp = TestProcessor(true, config: config, context: context)
        p.context.stageInstances = [tp]
        wait(for: [didInitExpectation], timeout: 1)
        
        /// start and stop the pipeline
        delegate.asyncExpectation = didStartExpectation
        p.start()
        wait(for: [didStartExpectation], timeout: 1)
        delegate.asyncExpectation = didStopExpectation
        p.stop()
        wait(for: [didStopExpectation], timeout: 1)
    }
    
    func testEmptyPipeline() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        
        // init the pipeline with no stages
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()
        config.stages = []
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        wait(for: [didInitExpectation], timeout: 1)
        
        // start and stop the pipeline
        delegate.asyncExpectation = didStartExpectation
        p.start()
        wait(for: [didStartExpectation], timeout: 1)
        XCTAssertFalse(p.context.isActive)
        delegate.asyncExpectation = didStopExpectation
        p.stop()
        wait(for: [didStopExpectation], timeout: 1)
        XCTAssertFalse(p.context.isActive)
    }
    
    /// integration test
    func testSpeechProcessors() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()

        // init the pipeline
        delegate.asyncExpectation = didInitExpectation
        //config.stages = [.vad]
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        wait(for: [didInitExpectation], timeout: 1)
        delegate.reset()
        
        // add stages
        let processor = TestProcessor(true, config: config, context: p.context)
        p.context.stageInstances = [processor]
        delegate.asyncExpectation = didStartExpectation
        p.start()
        wait(for: [didStartExpectation], timeout: 1)
        XCTAssert(p.context.isActive)
        delegate.asyncExpectation = didStopExpectation
        p.stop()
        wait(for: [didStopExpectation], timeout: 1)
        XCTAssertFalse(p.context.isActive)
    }
}

class SpeechPipelineTestDelegate: SpeechEventListener {
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didDidInit: Bool = false
    var activated: Bool = false
    var didDidStart: Bool = false
    var didDidStop: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didDidInit = false
        asyncExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {}
    
    func didDeactivate() {}
    
    func failure(speechError: Error) {}
    
    func didTimeout() {}
    
    func didActivate() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.activated = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didInit() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidInit = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didStart() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidStart = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func didStop() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidStop = true
        self.asyncExpectation?.fulfill()
        self.asyncExpectation = nil
    }
    
    func setupFailed(_ error: String) {}
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}

class TestProcessor: SpeechProcessor {
    func process(_ frame: Data) { }
    
    var configuration: SpeechConfiguration
    var delegate: SpeechEventListener?
    var context: SpeechContext
    var isSpeechProcessor: Bool = false
    
    init(_ isSpeechProcessor: Bool, config: SpeechConfiguration, context: SpeechContext) {
        self.configuration = config
        self.context = context
        self.isSpeechProcessor = isSpeechProcessor
    }
    
    func startStreaming() {
        context.isActive = isSpeechProcessor ? true: false
    }
    
    func stopStreaming() {
        context.isActive = isSpeechProcessor ? false: true
    }
}
