//
//  NLUTensorflowTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 5/18/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
@testable import TensorFlowLite
@testable import Spokestack
import XCTest

class NLUTensorflowTest: XCTestCase {
    func testInvoke() {
        let i = try! Interpreter(modelPath: NLUModel.path)
        try! i.allocateTensors()
        _ = NLUModel.input.withUnsafeBytes { try! i.copy(Data($0), toInputAt: 0) }
        _ = try! i.invoke()
        let output = try! i.output(at: NLUModel.validIndex)
        XCTAssertEqual(output.data, NLUModel.outputData)
        let result = output.data.toArray(type: Int32.self, count: output.data.count/4)
        XCTAssertEqual(result, [0, 0, 0, 0, 0, 0, 0, 0])
    }
    
    func testInit() {
        // bad config calls delegate.failure
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        config.nluModelMetadataPath = SharedTestMocks.createModelMetadataPath()
        let delegate = TestNLUDelegate()
        let didFailExpectation = expectation(description: "unsuccessful initialization calls TestNLUDelegate.failure")
        delegate.asyncExpectation = didFailExpectation
        let _ = try! NLUTensorflow([delegate], configuration: config)
        wait(for: [didFailExpectation], timeout: 5)
        XCTAssert(delegate.didFail)
        delegate.reset()
        
        // good config can init
        config.nluModelPath = NLUModel.path
        let _ = try! NLUTensorflow(configuration: config)
        XCTAssertFalse(delegate.didFail)
    }
    
    func testClassify() {
        // unsuccessful classification calls delegate.failure
        let config = SpeechConfiguration()
        config.nluVocabularyPath = SharedTestMocks.createVocabularyPath()
        config.nluModelMetadataPath = SharedTestMocks.createModelMetadataPath()
        config.nluModelPath = NLUModel.path
        let delegate = TestNLUDelegate()
        let nlu = try! NLUTensorflow([delegate], configuration: config)
        nlu.configuration.nluMaxTokenLength = -1
        let didFailExpectation = expectation(description: "unsuccessful classify calls TestNLUDelegate.failure")
        delegate.asyncExpectation = didFailExpectation
        nlu.classify(utterance: "")
        wait(for: [didFailExpectation], timeout: 5)
        XCTAssertFalse(delegate.didClassify)
        XCTAssert(delegate.didFail)
        
        // successful classification calls delegate.classify
        nlu.configuration.nluMaxTokenLength = 128
        delegate.reset()
        let didSucceedExpectation = expectation(description: "successful classification calls TestNLUDelegate.classify")
        delegate.asyncExpectation = didSucceedExpectation
        nlu.classify(utterance: "")
        wait(for: [didSucceedExpectation], timeout: 5)
        XCTAssert(delegate.didClassify)
        XCTAssertFalse(delegate.didFail)
    }
}

class TestNLUDelegate: SpokestackDelegate {
    // Spy pattern for the system under test.
    // asyncExpectation lets the caller's test know when the delegate has been called.
    var didClassify: Bool = false
    var didFail: Bool = false
    var asyncExpectation: XCTestExpectation?
    
    func reset() {
        didClassify = false
        didFail = false
        asyncExpectation = .none
    }
    
    func classification(result: NLUResult) {
        asyncExpectation?.fulfill()
        didClassify = true
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    func failure(error: Error) {
        asyncExpectation?.fulfill()
        didFail = true
    }
}
