//
//  TFLiteKeywordRecognizerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 12/14/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import CryptoKit
@testable import TensorFlowLite
@testable import Spokestack
import XCTest

class TFLiteKeywordRecognizerTest: XCTestCase {
    let delegate = TFLiteKeywordecognizerTestDelegate()
    let config = SpeechConfiguration()
    var context: SpeechContext?
    var recognizer: TFLiteKeywordRecognizer?
    
    override func setUp() {
        self.config.keywordEncodeModelPath = MockKeywordModels.encodePath
        self.config.keywordFilterModelPath = MockKeywordModels.filterPath
        self.config.keywordDetectModelPath = MockKeywordModels.detectPath
        self.context = SpeechContext(config)
        self.config.keywordMelFrameLength = 16
        self.recognizer = TFLiteKeywordRecognizer(config, context: self.context!)
    }
    
    func testInvoke() {
        // filter
        let filter = try! Interpreter(modelPath: MockKeywordModels.filterPath)
        try! filter.allocateTensors()
        _ = MockKeywordModels.filterInput.withUnsafeBytes { try! filter.copy(Data($0), toInputAt: 0) }
        _ = try! filter.invoke()
        let filterOutput = try! filter.output(at: MockKeywordModels.validIndex)
        XCTAssertEqual(filterOutput.data, MockKeywordModels.filterOutputData)
        let filterResult = filterOutput.data.toArray(type: Int32.self, count: filterOutput.data.count/4)
        XCTAssertEqual(filterResult, MockKeywordModels.filterOutput)
        
        // encode
        let encoder = try! Interpreter(modelPath: MockKeywordModels.encodePath)
        try! encoder.allocateTensors()
        _ = MockKeywordModels.encodeInput.withUnsafeBytes { try! encoder.copy(Data($0), toInputAt: 0) }
        _ = MockKeywordModels.input.withUnsafeBytes { try! encoder.copy(Data($0), toInputAt: 1) }
        _ = try! encoder.invoke()
        let encoderOutput = try! encoder.output(at: MockKeywordModels.validIndex)
        XCTAssertEqual(encoderOutput.data, MockKeywordModels.encodeOutputData)
        let encoderResult = encoderOutput.data.toArray(type: Int32.self, count: encoderOutput.data.count/4)
        XCTAssertEqual(encoderResult, MockKeywordModels.encodeOutput)
        
        // detect
        let detect = try! Interpreter(modelPath: MockKeywordModels.detectPath)
        try! detect.allocateTensors()
        _ = MockKeywordModels.detectInput.withUnsafeBytes { try! detect.copy(Data($0), toInputAt: 0) }
        _ = try! detect.invoke()
        let detectOutput = try! detect.output(at: MockKeywordModels.validIndex)
        XCTAssertEqual(detectOutput.data, MockKeywordModels.detectOutputData)
        let detectResult = detectOutput.data.toArray(type: Int32.self, count: detectOutput.data.count/4)
        XCTAssertEqual(detectResult, MockKeywordModels.detectOutput)
    }
    
    func testStartStop() {
        self.context!.isActive = false
        self.recognizer?.startStreaming()
        self.recognizer?.stopStreaming()
    }
    
    func testProcess() {
        // setup
        self.recognizer?.context.addListener(self.delegate)
        self.recognizer?.context.isActive = true
        self.recognizer?.context.isSpeech = true
        self.recognizer?.startStreaming()
        let recognizeExpectation = XCTestExpectation(description: "process without failure.")
        let timeoutExpectation = XCTestExpectation(description: "process without failure.")
        let failureExpectation = XCTestExpectation(description: "process without failure.")
        self.delegate.asyncExpectation = failureExpectation
        self.delegate.didRecognizeExepctation = recognizeExpectation
        self.delegate.didTimeoutExpectation = timeoutExpectation
        
        // timeout
        for _ in 0...1 {
            self.recognizer?.process(Frame.voice(frameWidth: 20, sampleRate: 16000))
        }
        self.context?.isActive = false
        wait(for: [timeoutExpectation], timeout: 1)
        XCTAssert(self.delegate.timedOut)
        XCTAssertFalse(self.delegate.didError)
        XCTAssertFalse(self.delegate.recognized)
        
        // don't process if the pipeline isn't active
        delegate.reset()
        self.recognizer?.startStreaming()
        self.recognizer?.context.isSpeech = true
        self.recognizer?.context.isActive = false
        self.delegate.didTimeoutExpectation = timeoutExpectation
        self.delegate.didRecognizeExepctation = recognizeExpectation
        for _ in 0...1 {
            self.recognizer?.process(Frame.silence(frameWidth: 20, sampleRate: 8000))
        }
        XCTAssertFalse(self.recognizer!.context.isActive)
        XCTAssertFalse(self.delegate.timedOut)
        XCTAssertFalse(self.delegate.recognized)
        XCTAssertFalse(self.delegate.didError)
    }
}

fileprivate enum MockKeywordModels {
    static let filterInfo = (name: "mock_kw_filter", extension: "tflite")
    static let encodeInfo = (name: "mock_kw_encode", extension: "tflite")
    static let detectInfo = (name: "mock_kw_detect", extension: "tflite")
    static var filterPath: String = {
        let bundle = Bundle(for: TFLiteKeywordRecognizerTest.self)
        let p = bundle.path(forResource: filterInfo.name, ofType: filterInfo.extension)
        return p!
    }()
    static var encodePath: String = {
        let bundle = Bundle(for: TFLiteKeywordRecognizerTest.self)
        let p = bundle.path(forResource: encodeInfo.name, ofType: encodeInfo.extension)
        return p!
    }()
    static var detectPath: String = {
        let bundle = Bundle(for: TFLiteKeywordRecognizerTest.self)
        let p = bundle.path(forResource: detectInfo.name, ofType: detectInfo.extension)
        return p!
    }()
    static let input = [Int32](Array(repeating: 0, count: 128)).withUnsafeBufferPointer(Data.init)
    static let filterInput = [Int32](Array(repeating: 0, count: 257)).withUnsafeBufferPointer(Data.init)
    static let encodeInput = [Int32](Array(repeating: 0, count: 40)).withUnsafeBufferPointer(Data.init)
    static let detectInput = [Int32](Array(repeating: 0, count: 11776)).withUnsafeBufferPointer(Data.init)
    static let validIndex = 0
    static let shape: Tensor.Shape = [2]
    static let output = [Int32](Array(repeating: 0, count: 40))
    static let outputData = output.withUnsafeBufferPointer(Data.init)
    static let filterOutput = [Int32](Array(repeating: 0, count: 40))
    static let filterOutputData = filterOutput.withUnsafeBufferPointer(Data.init)
    static let encodeOutput = [Int32](Array(repeating: 0, count: 128))
    static let encodeOutputData = encodeOutput.withUnsafeBufferPointer(Data.init)
    static let detectOutput = [Int32](arrayLiteral: 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    static let detectOutputData = detectOutput.withUnsafeBufferPointer(Data.init)
}

class TFLiteKeywordecognizerTestDelegate: SpokestackDelegate {
    var didError: Bool = false
    var recognized: Bool = false
    var timedOut: Bool = false
    var asyncExpectation: XCTestExpectation?
    var didRecognizeExepctation: XCTestExpectation?
    var didTimeoutExpectation: XCTestExpectation?
    
    func failure(error: Error) {
        print(error)
        guard let _ = asyncExpectation else {
            XCTFail("TFLiteKeywordRecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didError = true
        self.asyncExpectation?.fulfill()
    }
    
    func reset() {
        self.didError = false
        self.recognized = false
        self.timedOut = false
        self.asyncExpectation = .none
        self.didRecognizeExepctation = .none
        self.didTimeoutExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {
        print(result)
        guard let _ = didRecognizeExepctation else {
            XCTFail("TFLiteKeywordecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.recognized = true
        self.didRecognizeExepctation?.fulfill()
    }
    
    func didTimeout() {
        guard let _ = didTimeoutExpectation else {
            XCTFail("TFLiteKeywordecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.timedOut = true
        self.didTimeoutExpectation?.fulfill()
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}
