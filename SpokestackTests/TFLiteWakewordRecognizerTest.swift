//
//  TFLiteWakewordRecognizerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 5/22/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import CryptoKit
@testable import TensorFlowLite
@testable import Spokestack
import XCTest

class TFLiteWakewordRecognizerTest: XCTestCase {
    
    let context = SpeechContext()
    let delegate = TFLiteWakewordRecognizerTestDelegate()
    let config = SpeechConfiguration()
    var tflwr: TFLiteWakewordRecognizer?

    func hexStringToData(hexString: String) -> Data? {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        return data
    }
    
    override func setUp() {
        self.config.encodeModelPath = MockWakewordModels.encodePath
        self.config.filterModelPath = MockWakewordModels.filterPath
        self.config.detectModelPath = MockWakewordModels.detectPath

        self.tflwr = TFLiteWakewordRecognizer(config)
        self.tflwr?.context = context
        //let filterHexString = filter.map { String(format: "%02hhx", $0) }.joined()
        //let filterData = hexStringToData(hexString: MockWakewordModels.filterString)
        //let _ = FileManager.default.createFile(atPath: MockWakewordModels.filterPath, contents: filterData, attributes: .none)
    }
    
    func testInvoke() {
        // filter
        let filter = try! Interpreter(modelPath: MockWakewordModels.filterPath)
        try! filter.allocateTensors()
        _ = MockWakewordModels.filterInput.withUnsafeBytes { try! filter.copy(Data($0), toInputAt: 0) }
        _ = try! filter.invoke()
        let filterOutput = try! filter.output(at: MockWakewordModels.validIndex)
        XCTAssertEqual(filterOutput.data, MockWakewordModels.filterOutputData)
        let filterResult = filterOutput.data.toArray(type: Int32.self, count: filterOutput.data.count/4)
        XCTAssertEqual(filterResult, MockWakewordModels.filterOutput)
        
        // encode
        let encoder = try! Interpreter(modelPath: MockWakewordModels.encodePath)
        try! encoder.allocateTensors()
        _ = MockWakewordModels.encodeInput.withUnsafeBytes { try! encoder.copy(Data($0), toInputAt: 0) }
        _ = MockWakewordModels.input.withUnsafeBytes { try! encoder.copy(Data($0), toInputAt: 1) }
        _ = try! encoder.invoke()
        let encoderOutput = try! encoder.output(at: MockWakewordModels.validIndex)
        XCTAssertEqual(encoderOutput.data, MockWakewordModels.encodeOutputData)
        let encoderResult = encoderOutput.data.toArray(type: Int32.self, count: encoderOutput.data.count/4)
        XCTAssertEqual(encoderResult, MockWakewordModels.encodeOutput)
        
        // detect
        let detect = try! Interpreter(modelPath: MockWakewordModels.detectPath)
        try! detect.allocateTensors()
        _ = MockWakewordModels.detectInput.withUnsafeBytes { try! detect.copy(Data($0), toInputAt: 0) }
        _ = try! detect.invoke()
        let detectOutput = try! detect.output(at: MockWakewordModels.validIndex)
        XCTAssertEqual(detectOutput.data, MockWakewordModels.detectOutputData)
        let detectResult = detectOutput.data.toArray(type: Int32.self, count: detectOutput.data.count/4)
        XCTAssertEqual(detectResult, MockWakewordModels.detectOutput)
    }
    
    func testStartStop() {
        // start
        self.context.isActive = false
        self.tflwr?.startStreaming(context: self.context)
        XCTAssert(self.context.isStarted)
        // stop
        self.tflwr?.stopStreaming(context: self.context)
        XCTAssertFalse(self.context.isStarted)
    }
    
    func testActivatetDeactivate() {
        // start
        self.context.isActive = false
        self.tflwr?.startStreaming(context: self.context)
        self.tflwr?.process(Frame.voice(frameWidth: 10, sampleRate: 8000))
        XCTAssert(self.context.isSpeech)
        // stop
        self.tflwr?.process(Frame.silence(frameWidth: 10, sampleRate: 8000))
        XCTAssertFalse(self.context.isSpeech)
    }
    
    func testProcess() {
        // setup
        let successExpectation = XCTestExpectation(description: "process without failure.")
        self.delegate.didActivateExpectation = successExpectation
        self.tflwr?.configuration?.vadMode = .HighlyPermissive
        
        // process
        self.context.isActive = false
        self.context.isSpeech = false
        // NB: the detect model will always output 1.0 no matter the input
        self.tflwr?.process(Frame.voice(frameWidth: 10, sampleRate: 16000))
        wait(for: [successExpectation], timeout: 5)
        XCTAssert(self.context.isActive)
        XCTAssertFalse(self.delegate.didError)
    }
}

fileprivate enum MockWakewordModels {
    static let filterInfo = (name: "mock_filter", extension: "tflite")
    static let encodeInfo = (name: "mock_encoder", extension: "tflite")
    static let detectInfo = (name: "mock_detector", extension: "tflite")
    static let input = [Int32](Array(repeating: 0, count: 128)).withUnsafeBufferPointer(Data.init)
    static let filterInput = [Int32](Array(repeating: 0, count: 257)).withUnsafeBufferPointer(Data.init)
    static let encodeInput = [Int32](Array(repeating: 0, count: 40)).withUnsafeBufferPointer(Data.init)
    static let detectInput = [Int32](Array(repeating: 0, count: 12800)).withUnsafeBufferPointer(Data.init)
    static let validIndex = 0
    static let shape: TensorShape = [2]
    static let output = [Int32](Array(repeating: 0, count: 40))
    static let outputData = output.withUnsafeBufferPointer(Data.init)
    static let filterOutput = [Int32](Array(repeating: 0, count: 40))
    static let filterOutputData = filterOutput.withUnsafeBufferPointer(Data.init)
    static let encodeOutput = [Int32](Array(repeating: 0, count: 128))
    static let encodeOutputData = encodeOutput.withUnsafeBufferPointer(Data.init)
    static let detectOutput = [Int32](arrayLiteral: 1065353216)
    static let detectOutputData = detectOutput.withUnsafeBufferPointer(Data.init)
    static var filterPath: String = {
        let bundle = Bundle(for: TFLiteWakewordRecognizerTest.self)
        let p = bundle.path(forResource: filterInfo.name, ofType: filterInfo.extension)
        return p!
    }() // String = NSTemporaryDirectory() + MockWakewordModels.filterInfo.name + "." + MockWakewordModels.filterInfo.extension
    static var encodePath: String = {
        let bundle = Bundle(for: TFLiteWakewordRecognizerTest.self)
        let p = bundle.path(forResource: encodeInfo.name, ofType: encodeInfo.extension)
        return p!
    }()
    static var detectPath: String = {
        let bundle = Bundle(for: TFLiteWakewordRecognizerTest.self)
        let p = bundle.path(forResource: detectInfo.name, ofType: detectInfo.extension)
        return p!
    }()
}

class TFLiteWakewordRecognizerTestDelegate: SpeechEventListener {
    // Spy pattern for the system under test.
    // asyncExpectation lets the caller's test know when the delegate has been called.
    var didError: Bool = false
    var deactivated: Bool = false
    var activated: Bool = false
    var asyncExpectation: XCTestExpectation?
    var didActivateExpectation: XCTestExpectation?

    func reset() {
        self.didError = false
        self.deactivated = false
        self.activated = false
        asyncExpectation = .none
        self.didActivateExpectation = .none
    }
    
    func didRecognize(_ result: SpeechContext) {}
    
    func failure(speechError: Error) {
        print(speechError)
        guard let _ = asyncExpectation else {
            XCTFail("TFLiteWakewordRecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.didError = true
        self.asyncExpectation?.fulfill()
    }
    
    func didTimeout() {}
    
    func didActivate() {
        guard let _ = self.didActivateExpectation else {
            XCTFail("TFLiteWakewordRecognizerTestDelegate was not setup correctly. Missing XCTExpectation reference")
            return
        }
        self.activated = true
        self.didActivateExpectation?.fulfill()
    }
    
    func didDeactivate() {
        self.deactivated = true
    }
    
    func didInit() {}
    
    func didStart() {}
    
    func didStop() {}
    
    func setupFailed(_ error: String) {}
    
    func didTrace(_ trace: String) {
        print(trace)
    }
}
