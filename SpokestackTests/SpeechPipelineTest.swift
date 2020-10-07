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
        let context = SpeechContext(config)

        // successful init calls didInit
        let _ = SpeechPipeline(configuration: config, listeners: [delegate], stages: [], context: context)
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
        let p = SpeechPipeline(configuration: config, listeners: [delegate], stages: [tp], context: context)
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
        let context = SpeechContext(config)

        // init the pipeline
        delegate.asyncExpectation = didInitExpectation
        let p = SpeechPipeline(configuration: config, listeners: [delegate], stages: [], context: context)
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
        let didDeactivateExpectation = expectation(description: "didDeactivateExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate.deactivate as the result of stopStreaming method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testStartStop calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()
        let context = SpeechContext(config)

        // init the pipeline
        let tp = TestProcessor(true, config: config, context: context)
        let p = SpeechPipeline(configuration: config, listeners: [], stages: [tp], context: context)
        p.context.addListener(delegate)

        
        /// start and stop the pipeline
        delegate.asyncExpectation = didStartExpectation
        delegate.deactivateExpectation = didDeactivateExpectation
        p.start()
        wait(for: [didStartExpectation], timeout: 1)
        delegate.asyncExpectation = didStopExpectation
        p.stop()
        wait(for: [didStopExpectation, didDeactivateExpectation], timeout: 1)
    }
    
    func testEmptyPipeline() {
        let didInitExpectation = expectation(description: "didInitExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didInit method completion")
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        
        // init the pipeline with no stages
        delegate.asyncExpectation = didInitExpectation
        let config = SpeechConfiguration()
        let context = SpeechContext(config)
        let p = SpeechPipeline(configuration: config, listeners: [delegate], stages: [], context: context)
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
    
    /// stages test
    func testSpeechProcessors() {
        let didStartExpectation = expectation(description: "didStartExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStart method completion")
        let didDeactivateExpectation = expectation(description: "didDeactivateExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate.deactivate as the result of stopStreaming method completion")
        let didStopExpectation = expectation(description: "didStopExpectation fulfills when testSpeechProcessors calls SpeechPipelineTestDelegate as the result of didStop method completion")
        let delegate = SpeechPipelineTestDelegate()
        let config = SpeechConfiguration()
        let context = SpeechContext(config)

        // init the pipeline
        
        // add stages
        let processor = TestProcessor(true, config: config, context: context)
        let stages = [processor]
        let p = SpeechPipeline(configuration: config, listeners: [], stages: stages, context: context)
        XCTAssert(type(of: AudioController.sharedInstance.stages.first!) == type(of: stages.first!))
        p.context.addListener(delegate)
        delegate.asyncExpectation = didStartExpectation
        
        // start
        p.start()
        wait(for: [didStartExpectation], timeout: 1)
        XCTAssert(context.isActive)
        
        // stop
        delegate.asyncExpectation = didStopExpectation
        delegate.deactivateExpectation = didDeactivateExpectation
        p.stop()
        wait(for: [didDeactivateExpectation, didStopExpectation], timeout: 1)
        XCTAssertFalse(p.context.isActive)
    }
}

class SpeechPipelineBuilderTest: XCTestCase {
    func testBuild() {
        let delegate = SpeechPipelineTestDelegate()
        let didInit1Expectation = expectation(description: "didInitExpectation fulfills when testBuild calls SpeechPipelineTestDelegate as the result of build method completion")

        // a profile is requred
        XCTAssertThrowsError(try SpeechPipelineBuilder().addListener(delegate).build()) {
            XCTAssert($0.localizedDescription.count > 1)
        }

        // tflite
        delegate.asyncExpectation = didInit1Expectation
        let p1 = try! SpeechPipelineBuilder()
            .useProfile(.tfLiteWakewordAppleSpeech)
            .addListener(delegate)
            .setProperty("tracing", -1)
            .build()
        XCTAssertEqual(p1.configuration.tracing, .NONE)
        wait(for: [didInit1Expectation], timeout: 1)
        
        XCTAssert([WebRTCVAD.self, TFLiteWakewordRecognizer.self, AppleSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))

        // appleWW
        delegate.reset()
        let wakeActiveMax = 10000
        let level = Trace.Level.PERF
        let p2 = try! SpeechPipelineBuilder()
            .useProfile(.appleWakewordAppleSpeech)
            .setProperty("wakeActiveMax", wakeActiveMax.description)
            .setProperty("tracing", level)
            .build()
        XCTAssertEqual(wakeActiveMax, p2.configuration.wakeActiveMax)
        XCTAssert([WebRTCVAD.self, AppleWakewordRecognizer.self, AppleSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
        XCTAssertEqual(level, p2.configuration.tracing)

        // vadTrigger
        delegate.reset()
        let _ = try! SpeechPipelineBuilder()
            .useProfile(.vadTriggerAppleSpeech)
            .build()
        XCTAssert([WebRTCVAD.self, VADTrigger.self, AppleSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
        
        // p2t
        delegate.reset()
        let queue = DispatchQueue.main
        let p4 = try! SpeechPipelineBuilder()
            .useProfile(.pushToTalkAppleSpeech)
            .setDelegateDispatchQueue(queue)
            .build()
        XCTAssert(queue === p4.configuration.delegateDispatchQueue)
        XCTAssert([AppleSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
        
        // spokestack + tflite
        delegate.reset()
        let _ = try! SpeechPipelineBuilder()
            .useProfile(.tfLiteWakewordSpokestackSpeech)
            .build()
        XCTAssert([WebRTCVAD.self, TFLiteWakewordRecognizer.self, SpokestackSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
        
        // spokestack + vad
        delegate.reset()
        let _ = try! SpeechPipelineBuilder()
            .useProfile(.vadTriggerSpokestackSpeech)
            .build()
        XCTAssert([WebRTCVAD.self, VADTrigger.self, SpokestackSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
    }
}

class SpeechPipelineTestDelegate: SpokestackDelegate {
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
    
    func failure(error: Error) {}
    
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
    var delegates: [SpokestackDelegate] = []
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
        context.dispatch { $0.didDeactivate?() }
    }
}
