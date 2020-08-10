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
        let context = SpeechContext(config)
        config.fftHopLength = 30

        // successful init calls didInit
        let tp = TestProcessor(true, config: config, context: context)
        config.stages = [tp]
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        wait(for: [didInitExpectation], timeout: 1)
        XCTAssert(delegate.didDidInit)
        
        // successful init sets config property
        XCTAssertEqual(p.configuration.fftHopLength, 30)
    }
    
    /// activate & deactivate
    func testActivateDeactivate() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testActivateDeactivate calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didActivateExpectation = expectation(description: "didActivateExpectation fulfills when testActivateDeactivate calls SpeechPipelineTestDelegate as the result of activate method completion")
        let didDeactivateExpectation = expectation(description: "didDeactivateExpectation fulfills when testActivateDeactivate calls SpeechPipelineTestDelegate as the result of deactivate method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()

        // init the pipeline
        delegate.asyncExpectation = didInitExpectation
        let p = SpeechPipeline(configuration: config, listeners: [delegate])
        wait(for: [didInitExpectation], timeout: 1)
        
        // activate and deactivate the pipeline
        delegate.reset()
        delegate.asyncExpectation = didActivateExpectation
        p.activate()
        wait(for: [didActivateExpectation], timeout: 1)
        XCTAssert(p.context.isActive)
        delegate.deactivateExpectation = didDeactivateExpectation
        p.deactivate()
        wait(for: [didDeactivateExpectation], timeout: 1)
        XCTAssert(!p.context.isActive)
    }
    
    /// start & stop
    func testStartStop() {
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()
        let context = SpeechContext(config)

        // init the pipeline
        let tp = TestProcessor(true, config: config, context: context)
        config.stages = [tp]
        let p = SpeechPipeline(configuration: config, listeners: [])
        p.context.addListener(delegate)

        
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
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()
        let context = SpeechContext(config)

        // init the pipeline
        
        // add stages
        let processor = TestProcessor(true, config: config, context: context)
        config.stages = [processor]
        let p = SpeechPipeline(configuration: config, listeners: [])
        p.context.addListener(delegate)
        delegate.asyncExpectation = didStartExpectation
        p.start()
        wait(for: [didStartExpectation], timeout: 1)
        delegate.asyncExpectation = didStopExpectation
        p.stop()
        wait(for: [didStopExpectation], timeout: 1)
        XCTAssertFalse(p.context.isActive)
    }
}

class SpeechPipelineBuilderTest: XCTestCase {
    func testBuild() {
        let delegate = SpeechPipelineTestDelegate()
        let didInit1Expectation = expectation(description: "didInitExpectation fulfills when testBuild calls SpeechPipelineTestDelegate as the result of build method completion")

        // tflite
        delegate.asyncExpectation = didInit1Expectation
        let p1 = SpeechPipelineBuilder()
            .useProfile(.tfLiteWakewordAppleSpeech)
            .addListener(delegate)
            .build()
        wait(for: [didInit1Expectation], timeout: 1)
        XCTAssert(compare(expected: [WebRTCVAD.self, TFLiteWakewordRecognizer.self, AppleSpeechRecognizer.self], actual: p1.configuration.stages.enumerated()))

        
        // appleWW
        delegate.reset()
        let wakeActiveMax = 10000
        let p2 = SpeechPipelineBuilder()
            .useProfile(.appleWakewordAppleSpeech)
            .setProperty("wakeActiveMax", wakeActiveMax.description)
            .build()
        XCTAssertEqual(wakeActiveMax, p2.configuration.wakeActiveMax)
        XCTAssert(compare(expected: [WebRTCVAD.self, AppleWakewordRecognizer.self, AppleSpeechRecognizer.self], actual: p2.configuration.stages.enumerated()))

        // vadTrigger
        delegate.reset()
        let p3 = SpeechPipelineBuilder()
            .useProfile(.vadTriggerAppleSpeech)
            .build()
        XCTAssert(compare(expected: [WebRTCVAD.self, VADTrigger.self, AppleSpeechRecognizer.self], actual: p3.configuration.stages.enumerated()))
        
        // p2t
        delegate.reset()
        let queue = DispatchQueue.main
        let p4 = SpeechPipelineBuilder()
            .useProfile(.pushToTalkAppleSpeech)
            .setDelegateDispatchQueue(queue)
            .build()
        XCTAssert(queue === p4.configuration.delegateDispatchQueue)
        XCTAssert(compare(expected: [AppleSpeechRecognizer.self], actual: p4.configuration.stages.enumerated()))
    }
    
    private func compare(expected: [NSObject.Type], actual: EnumeratedSequence<[SpeechProcessor]>) -> Bool {
        var accumulator: [Bool] = []
        for (i, s) in actual {
            accumulator.append(expected[i] == (type(of: s)))
        }
        return accumulator.reduce(true, { $0 && $1 })
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
    var deactivateExpectation: XCTestExpectation?
    
    func reset() {
        didDidInit = false
        asyncExpectation = .none
        deactivateExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {}
    
    func didDeactivate() {
        guard let _ = deactivateExpectation else {
            XCTFail("SpeechPipelineTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.activated = false
        self.deactivateExpectation?.fulfill()
        self.deactivateExpectation = nil
    }
    
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
