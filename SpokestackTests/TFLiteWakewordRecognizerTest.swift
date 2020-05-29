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
        // setup
        let tflwr = TFLiteWakewordRecognizer.sharedInstance
        let context = SpeechContext()
        let delegate = TFLiteWakewordRecognizerTestDelegate()
        let config = SpeechConfiguration()
        config.encodeModelPath = MockWakewordModels.encodePath
        config.filterModelPath = MockWakewordModels.filterPath
        config.detectModelPath = MockWakewordModels.detectPath
        tflwr.configuration = config
        tflwr.context = context
        tflwr.delegate = delegate
        
        // start
        context.isActive = false
        tflwr.startStreaming(context: context)
        XCTAssert(context.isStarted)
        // stop
        tflwr.stopStreaming(context: context)
        XCTAssertFalse(context.isStarted)
    }
    
    func testActivatetDeactivate() {
        // setup
        let tflwr = TFLiteWakewordRecognizer.sharedInstance
        let context = SpeechContext()
        let delegate = TFLiteWakewordRecognizerTestDelegate()
        let config = SpeechConfiguration()
        config.encodeModelPath = MockWakewordModels.encodePath
        config.filterModelPath = MockWakewordModels.filterPath
        config.detectModelPath = MockWakewordModels.detectPath
        tflwr.configuration = config
        tflwr.context = context
        tflwr.delegate = delegate
        
        // start
        context.isActive = false
        tflwr.startStreaming(context: context)
        tflwr.activate(frame: Frame.voice(frameWidth: 10, sampleRate: 8000))
        XCTAssert(context.isSpeech)
        tflwr.deactivate()
        XCTAssertFalse(context.isSpeech)
    }
    
    func testProcess() {
        // setup
        let tflwr = TFLiteWakewordRecognizer.sharedInstance
        let context = SpeechContext()
        let delegate = TFLiteWakewordRecognizerTestDelegate()
        let config = SpeechConfiguration()
        let successExpectation = XCTestExpectation(description: "process without failure.")
        delegate.didActivateExpectation = successExpectation
        config.encodeModelPath = MockWakewordModels.encodePath
        config.filterModelPath = MockWakewordModels.filterPath
        config.detectModelPath = MockWakewordModels.detectPath
        config.vadMode = .HighlyPermissive
        tflwr.configuration = config
        tflwr.context = context
        tflwr.delegate = delegate
        
        // process
        context.isActive = false
        context.isSpeech = false
        // NB: the detect model will always output 1.0 no matter the input
        tflwr.process(Frame.voice(frameWidth: 10, sampleRate: 16000))
        wait(for: [successExpectation], timeout: 5)
        XCTAssert(context.isActive)
        XCTAssertFalse(delegate.didError)
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
    // static let filterString = "5b3078316330302c203078303030302c203078353434362c203078346333332c203078303030302c203078313230302c203078316330302c203078303430302c0a3078303830302c203078306330302c203078313030302c203078313430302c203078303030302c203078313830302c203078313230302c203078303030302c0a3078303330302c203078303030302c203078313430302c203078303030302c203078313430302c203078303030302c203078376330302c203078303030302c0a3078313430302c203078303030302c203078323430302c203078303030302c203078303030302c203078303030302c203078303130302c203078303030302c0a3078386330302c203078303030302c203078303430302c203078303030302c203078663430312c203078303030302c203078663030312c203078303030302c0a3078633430302c203078303030302c203078333830302c203078303030302c203078303130302c203078303030302c203078306330302c20303030302c0a3078303830302c203078306330302c203078303430302c203078303830302c203078303830302c203078303030302c203078303830302c20303030302c0a3078303330302c203078303030302c203078313330302c203078303030302c203078366436392c203078366535662c203078373237352c20366537342c0a3078363936642c203078363535662c203078373636352c203078373237332c203078363936662c203078366530302c203078376566662c20666666662c0a3078303430302c203078303030302c203078313030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078306630302c203078303030302c203078346434632c20343935322c0a3078323034332c203078366636652c203078373636352c203078373237342c203078363536342c203078326530302c203078303030302c20306530302c0a3078313830302c203078303430302c203078303830302c203078306330302c203078313030302c203078313430302c203078306530302c20303030302c0a3078313430302c203078303030302c203078316330302c203078303030302c203078323030302c203078303030302c203078323430302c20303030302c0a3078323430302c203078303030302c203078303230302c203078303030302c203078323030312c203078303030302c203078643430302c20303030302c0a3078303130302c203078303030302c203078303030302c203078303030302c203078303130302c203078303030302c203078303130302c20303030302c0a3078303030302c203078303030302c203078303430302c203078303030302c203078366436312c203078363936652c203078303030302c20303630302c0a3078303830302c203078303430302c203078303630302c203078303030302c203078303430302c203078303030302c203078613030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c203078303030302c20303030302c0a3078633666662c203078666666662c203078313030302c203078303030302c203078303230302c203078303030302c203078313430302c20303030302c0a3078323430302c203078303030302c203078303230302c203078303030302c203078303130302c203078303030302c203078323830302c20303030302c0a3078303830302c203078303030302c203078343936342c203078363536652c203078373436392c203078373437392c203078303030302c20303030302c0a3078303430302c203078303630302c203078303430302c203078303030302c203078303030302c203078306530302c203078313430302c20303430302c0a3078303030302c203078303830302c203078306330302c203078313030302c203078306530302c203078303030302c203078313030302c20303030302c0a3078303130302c203078303030302c203078313430302c203078303030302c203078316330302c203078303030302c203078303230302c20303030302c0a3078303130302c203078303030302c203078303130312c203078303030302c203078303630302c203078303030302c203078363936652c20373037352c0a3078373437332c203078303030302c203078666366662c203078666666662c203078303430302c203078303430302c203078303430302c20303030305d0a"
}

class TFLiteWakewordRecognizerTestDelegate: PipelineDelegate, SpeechEventListener {
    /// Spy pattern for the system under test.
    /// asyncExpectation lets the caller's test know when the delegate has been called.
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
