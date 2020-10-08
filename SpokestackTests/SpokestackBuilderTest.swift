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
        let editor = Editor()
        let s2 = try! SpokestackBuilder()
            .addDelegate(delegate)
            .usePipelineProfile(.vadTriggerSpokestackSpeech)
            .setDelegateDispatchQueue(queue)
            .setProperty("wakeActiveMin", wakeActiveMin.description)
            .setProperty("tracing", level)
            .setProperty("nluVocabularyPath", SharedTestMocks.createVocabularyPath())
            .setProperty("nluModelMetadataPath", SharedTestMocks.createModelMetadataPath())
            .setProperty("nluModelPath", NLUModel.path)
            .setTranscriptEditor(editor)
            .build()
        XCTAssert([WebRTCVAD.self, VADTrigger.self, SpokestackSpeechRecognizer.self].areSameOrderedType(other:  AudioController.sharedInstance.stages))
        XCTAssert(queue === s2.configuration.delegateDispatchQueue)
        XCTAssertEqual(wakeActiveMin, s2.configuration.wakeActiveMin)
        XCTAssertEqual(level, s2.configuration.tracing)
        
        // automatic classification + editing
        let recognizer = Recognizer(s2.context, s2.configuration)
        recognizer.process(Frame.silence(frameWidth: 0, sampleRate: 0))
        let didSucceedExpectation = expectation(description: "successful classification calls TestNLUDelegate.classify")
        delegate.asyncExpectation = didSucceedExpectation
        wait(for: [didSucceedExpectation], timeout: 1)
        XCTAssert(delegate.didRecognize)
        XCTAssert(delegate.didClassify)
        XCTAssertFalse(delegate.didFail)
        XCTAssertEqual("A deaf cabbage.", delegate.utterance)
        
        // build with invalid tracing level
        let s3 = try! SpokestackBuilder()
            .setProperty("tracing", -1)
            .build()
        XCTAssertEqual(s3.configuration.tracing, .NONE)
    }
}

class Editor: TranscriptEditor {
    func editTranscript(transcript: String) -> String {
        return "A deaf cabbage."
    }
}

class Recognizer: SpeechProcessor {
    var configuration: SpeechConfiguration
    
    var context: SpeechContext
    
    func startStreaming() {}
    
    func stopStreaming() {}
    
    public init(_ context: SpeechContext, _ config: SpeechConfiguration) {
        self.context = context
        self.configuration = config
    }
    
    func process(_ frame: Data) {
        self.context.transcript = ".egabbac faed A"
        self.context.dispatch { $0.didRecognize?(self.context) }
    }
    
    
}

class SpokestackTestDelegate: SpokestackDelegate {
    
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
    var didDidInit: Bool = false
    var didRecognize: Bool = false
    var didClassify: Bool = false
    var didFail: Bool = false
    var utterance = ""
    var asyncExpectation: XCTestExpectation?
    var deactivateExpectation: XCTestExpectation?
    
    func reset() {
        didDidInit = false
        didRecognize = false
        didClassify = false
        utterance = ""
        asyncExpectation = .none
        deactivateExpectation = .none
    }
    
    func failure(error: Error) {
        self.didFail = true
    }
    
    func didRecognize(_ result: SpeechContext) {
        self.didRecognize = true
    }
    
    func classification(result: NLUResult) {
        self.didClassify = true
        self.utterance = result.utterance
        self.asyncExpectation?.fulfill()
    }
}
