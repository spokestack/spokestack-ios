//
//  TFLiteKeywordViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Noel Weichbrodt on 12/10/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import UIKit
import Spokestack
import AVFoundation

class TFLiteKeywordViewController: UIViewController {
    
    lazy var startRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start", for: .normal)
        button.addTarget(self,
                         action: #selector(TFLiteKeywordViewController.startRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.blue, for: .normal)
        
        return button
    }()
    
    var stopRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Stop", for: .normal)
        button.addTarget(self,
                         action: #selector(TFLiteKeywordViewController.stopRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.blue, for: .normal)
        
        
        return button
    }()
    
    lazy private var pipeline: SpeechPipeline = {
        return try! SpeechPipelineBuilder()
            .addListener(self)
            .useProfile(.vadTriggerSpokestackSpeech)
            .setProperty("tracing", ".DEBUG")
            .setProperty("vadFallDelay", "1600")
            .setDelegateDispatchQueue(DispatchQueue.main)
            .build()
    }()
    
    override func loadView() {
        
        super.loadView()
        self.view.backgroundColor = .white
        self.title = "Keyword Recognizer"
        
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(TFLiteKeywordViewController.dismissViewController(_:)))
        self.navigationItem.rightBarButtonItem = doneBarButtonItem
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.startRecordingButton)
        self.view.addSubview(self.stopRecordingButton)
        
        self.startRecordingButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.startRecordingButton.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.startRecordingButton.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        
        self.stopRecordingButton.topAnchor.constraint(equalTo: self.startRecordingButton.bottomAnchor, constant: 50.0).isActive = true
        self.stopRecordingButton.leftAnchor.constraint(equalTo: self.startRecordingButton.leftAnchor).isActive = true
        self.stopRecordingButton.rightAnchor.constraint(equalTo: self.startRecordingButton.rightAnchor).isActive = true
        
        do {
            self.pipeline = try self.initPipeline()
        } catch let error {
            print("couldn't initialize pipeline becuase \(error)")
        }
    }
    
    func initPipeline() throws -> SpeechPipeline {
        let c = SpeechConfiguration()
        guard let filterPath = Bundle(for: type(of: self)).path(forResource: c.keywordFilterModelName, ofType: "tflite") else {
            throw CommandModelError.filter("could not find \(c.keywordFilterModelName).tflite in bundle \(self.debugDescription)")
        }
        guard let encodePath = Bundle(for: type(of: self)).path(forResource: c.keywordEncodeModelName, ofType: "tflite") else {
            throw CommandModelError.encode("could not find \(c.keywordEncodeModelName).tflite in bundle \(self.debugDescription)")
        }
        guard let detectPath = Bundle(for: type(of: self)).path(forResource: c.keywordDetectModelName, ofType: "tflite") else {
            throw CommandModelError.detect("could not find \(c.keywordDetectModelName).tflite in bundle \(self.debugDescription)")
        }
        return try! SpeechPipelineBuilder()
            .addListener(self)
            .setDelegateDispatchQueue(DispatchQueue.main)
            .useProfile(.vadTriggerKeyword)
            .setProperty("tracing", Trace.Level.PERF)
            .setProperty("keywordDetectModelPath", detectPath)
            .setProperty("keywordEncodeModelPath", encodePath)
            .setProperty("keywordFilterModelPath", filterPath)
            .build()
    }
    
    @objc func startRecordingAction(_ sender: Any) {
        print("pipeline started")
        self.pipeline.start()
    }
    
    @objc func stopRecordingAction(_ sender: Any) {
        print("pipeline finished")
        self.pipeline.stop()
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

extension TFLiteKeywordViewController: SpokestackDelegate {
    
    func setupFailed(_ error: String) {
        print("setupFailed: " + error)
    }
    
    func didInit() {
        print("didInit")
    }
    
    func didStop() {
        print("didStop")
    }
    
    func didTimeout() {
        print("timeout")
    }
    
    func didActivate() {
        print("didActivate")
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    func didDeactivate() {
        print("didDeactivate")
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    func failure(error: Error) {
        print("failure \(String(describing: error))")
    }
    
    func didRecognize(_ result: SpeechContext) {
        print("didRecognize transcript \(result.transcript)")
    }
    
    func didRecognizePartial(_ result: SpeechContext) {
        print("didRecognizePartial transcript \(result.transcript)")
    }
    
    func didStart() {
        print("didStart")
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    func didTrace(_ trace: String) {
        print("didTrace: \(trace)")
    }
}
