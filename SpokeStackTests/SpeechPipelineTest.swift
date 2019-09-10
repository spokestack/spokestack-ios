//
//  SpeechPipelineTest.swift
//  SpokeStackTests
//
//  Created by Noel Weichbrodt on 9/6/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import XCTest
import SpokeStack

class SpeechPipelineTest: XCTestCase {
    
    /// init
    func testInit() {
        let delegate = SpeechPipelineTestDelegate()
        let didInitExpectation = expectation(description: "testInit calls SpeechPipelineTestDelegate as the result of didInit method completion")
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()
        config.fftHopLength = 30
        
        do {
            /// successful init calls didInit
            let p = try SpeechPipeline(TestProcessor(true), speechConfiguration: config, speechDelegate: delegate, wakewordService: TestProcessor(), wakewordDelegate: delegate, pipelineDelegate: delegate)
            wait(for: [didInitExpectation], timeout: 1)
            XCTAssert(delegate.didDidInit)
            
            /// successful init sets config property
            XCTAssert(p.speechConfiguration?.fftHopLength == 30)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
        
        /// NB init is marked as throws because it force-unwraps the pipelineDelegate, but since the pipelineDelegate is requred in the constructor, init cannot actually throw.
    }
    
    /// status
    func testStatus() {
        var delegate: SpeechPipelineTestDelegate
        let didInitExpectation = expectation(description: "testStatus calls SpeechPipelineTestDelegate as the result of didInit method completion")

        do {
            /// ensure that the pipeline retains a reference to the delegate
            delegate = SpeechPipelineTestDelegate()
            delegate.asyncExpectation = didInitExpectation
            let p = try SpeechPipeline(TestProcessor(true), speechConfiguration: SpeechConfiguration(), speechDelegate: delegate, wakewordService: TestProcessor(), wakewordDelegate: delegate, pipelineDelegate: delegate)
            wait(for: [didInitExpectation], timeout: 1)
            XCTAssert(p.status())
            delegate = SpeechPipelineTestDelegate()
            delegate.asyncExpectation = didInitExpectation
            XCTAssert(p.status())
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    /// setDelegates
    func testSetDelegates() {
        var delegate: SpeechPipelineTestDelegate
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testSetDelegates calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let activateExpectation = expectation(description: "activateExpectation fulfills when testSetDelegates calls SpeechPipelineTestDelegate as the result of activate method completion")

        do {
            /// init the pipeline
            delegate = SpeechPipelineTestDelegate()
            delegate.asyncExpectation = didInitExpectation
            let p = try SpeechPipeline(TestProcessor(true), speechConfiguration: SpeechConfiguration(), speechDelegate: delegate, wakewordService: TestProcessor(), wakewordDelegate: delegate, pipelineDelegate: delegate)
            wait(for: [didInitExpectation], timeout: 1)
            
            /// change the pipeline's delegates
            delegate = SpeechPipelineTestDelegate()
            delegate.asyncExpectation = activateExpectation
            p.setDelegates(delegate, wakewordDelegate: delegate)
            
            /// assert that the pipeline's delegate references (and pipeline's service delegates) have changed
            XCTAssert(delegate === p.speechDelegate)
            XCTAssert(delegate === p.wakewordDelegate)
            p.speechDelegate?.activate()
            wait(for: [activateExpectation], timeout: 1)
            XCTAssert(delegate.didActivate)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    /// activate & deactivate
    func testActivateDeactivate() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testActivateDeactivate calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let delegate = SpeechPipelineTestDelegate()
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()

        do {
            /// init the pipeline
            let p = try SpeechPipeline(TestProcessor(true), speechConfiguration: config, speechDelegate: delegate, wakewordService: TestProcessor(), wakewordDelegate: delegate, pipelineDelegate: delegate)
            wait(for: [didInitExpectation], timeout: 1)
            
            /// activate and deactivate the pipeline
            p.activate()
            XCTAssert(p.context.isActive)
            p.deactivate()
            XCTAssert(!p.context.isActive)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    /// start & stop
    func testStartStop() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let context = SpeechConfiguration()
        do {
            /// init the pipeline
            delegate.asyncExpectation = didInitExpectation
            let p = try SpeechPipeline(TestProcessor(true), speechConfiguration: context, speechDelegate: delegate, wakewordService: TestProcessor(), wakewordDelegate: delegate, pipelineDelegate: delegate)
            wait(for: [didInitExpectation], timeout: 1)
            
            /// start and stop the pipeline
            delegate.asyncExpectation = didStartExpectation
            p.start()
            wait(for: [didStartExpectation], timeout: 1)
            XCTAssert(!p.context.isActive)
            delegate.asyncExpectation = didStopExpectation
            p.stop()
            wait(for: [didStopExpectation], timeout: 1)
            XCTAssert(!p.context.isActive)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
    
    /// integration test
    func testSpeechProcessors() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let context = SpeechConfiguration()
        
        do {
            /// init the pipeline
            delegate.asyncExpectation = didInitExpectation
            let p = try SpeechPipeline(SpeechProcessors.appleSpeech.processor, speechConfiguration: context, speechDelegate: delegate, wakewordService: SpeechProcessors.appleWakeword.processor, wakewordDelegate: delegate, pipelineDelegate: delegate)
            wait(for: [didInitExpectation], timeout: 1)
            
            /// start and stop the pipeline
            delegate.asyncExpectation = didStartExpectation
            p.start()
            wait(for: [didStartExpectation], timeout: 1)
            XCTAssert(!p.context.isActive)
            delegate.asyncExpectation = didStopExpectation
            p.stop()
            wait(for: [didStopExpectation], timeout: 1)
            XCTAssert(!p.context.isActive)
        } catch let error {
            XCTFail(error.localizedDescription)
        }
    }
}

class SpeechPipelineTestDelegate: PipelineDelegate, SpeechEventListener {
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didDidInit: Bool = false
    var didActivate: Bool = false
    var didDidStart: Bool = false
    var didDidStop: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didDidInit = false
        asyncExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {}
    
    func deactivate() {}
    
    func didError(_ error: Error) {}
    
    func didTimeout() {}
    
    func activate() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didActivate = true
        self.asyncExpectation?.fulfill()
    }
    
    func didInit() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidInit = true
        self.asyncExpectation?.fulfill()
    }
    
    func didStart() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidStart = true
        self.asyncExpectation?.fulfill()
    }
    
    func didStop() {
        guard let _ = asyncExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didDidStop = true
        self.asyncExpectation?.fulfill()
    }
    
    func setupFailed(_ error: String) {}
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}

class TestProcessor: SpeechProcessor {
    var configuration: SpeechConfiguration?
    var delegate: SpeechEventListener?
    var isSpeechProcessor: Bool = false
    
    init() {}
    
    init(_ isSpeechProcessor: Bool) {
        self.isSpeechProcessor = isSpeechProcessor
    }
    
    func startStreaming(context: SpeechContext) {
        context.isActive = isSpeechProcessor ? true: false
    }
    
    func stopStreaming(context: SpeechContext) {
        context.isActive = false
    }
}
