//
//  TFLiteViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Noel Weichbrodt on 8/12/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import UIKit
import Spokestack
import AVFoundation

class TFLiteViewController: UIViewController {
    
    lazy var startRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start", for: .normal)
        button.addTarget(self,
                         action: #selector(TFLiteViewController.startRecordingAction(_:)),
                         for: .touchUpInside)
        button.setTitleColor(.purple, for: .normal)
        
        return button
    }()
    
    var stopRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Stop", for: .normal)
        button.addTarget(self,
                         action: #selector(TFLiteViewController.stopRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.purple, for: .normal)
        
        
        return button
    }()
    
    private var pipeline: SpeechPipeline?
    
    override func loadView() {
        
        super.loadView()
        self.view.backgroundColor = .white
        self.title = "TensorFlow Wakeword"
        
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(TFLiteViewController.dismissViewController(_:)))
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
        guard let filterPath = Bundle(for: type(of: self)).path(forResource: c.filterModelName, ofType: "lite") else {
            throw WakewordModelError.filter("could not find \(c.filterModelName).lite in bundle \(self.debugDescription)")
        }
        c.filterModelPath = filterPath
        guard let encodePath = Bundle(for: type(of: self)).path(forResource: c.encodeModelName, ofType: "lite") else {
            throw WakewordModelError.encode("could not find \(c.encodeModelName).lite in bundle \(self.debugDescription)")
        }
        c.encodeModelPath = encodePath
        guard let detectPath = Bundle(for: type(of: self)).path(forResource: c.detectModelName, ofType: "lite") else {
            throw WakewordModelError.detect("could not find \(c.detectModelName).lite in bundle \(self.debugDescription)")
        }
        c.detectModelPath = detectPath
        c.tracing = Trace.Level.PERF
        return SpeechPipeline(SpeechProcessors.appleSpeech.processor,
                              speechConfiguration: c,
                              speechDelegate: self,
                              wakewordService: SpeechProcessors.tfLiteWakeword.processor,
                              pipelineDelegate: self)
    }
    
    @objc func startRecordingAction(_ sender: Any) {
        print("pipeline started")
        self.pipeline?.start()
    }
    
    @objc func stopRecordingAction(_ sender: Any) {
        print("pipeline finished")
        self.pipeline?.stop()
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    func toggleStartStop() {
        DispatchQueue.main.async {
            self.stopRecordingButton.isEnabled.toggle()
            self.startRecordingButton.isEnabled.toggle()
        }
    }
}

extension TFLiteViewController: SpeechEventListener, PipelineDelegate {
    
    func setupFailed(_ error: String) {
        print("setupFailed: " + error)
    }
    
    func didInit() {
        print("didInit")
    }
    
    func didTimeout() {
        print("timeout")
    }
    
    func activate() {
        print("activate")
        self.pipeline?.activate()
    }
    
    func deactivate() {
        print("deactivate")
        self.pipeline?.deactivate()
    }
    
    func didError(_ error: Error) {
        print("didError \(String(describing: error))")
    }
    
    func didRecognize(_ result: SpeechContext) {
        print("didRecognize transcript \(result.transcript)")
    }
    
    func didStart() {
        print("didStart")
        self.toggleStartStop()
    }
    
    func didStop() {
        print("didStart")
        self.toggleStartStop()
    }
    
    func didTrace(_ trace: String) {
        print("didTrace: \(trace)")
    }
}

