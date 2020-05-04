//
//  ViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import UIKit
import Spokestack
import AVFoundation

class AppleWakewordViewController: UIViewController {
    
    lazy var startRecordingButton: UIButton = {
        let button: UIButton = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start", for: .normal)
        button.addTarget(self,
                         action: #selector(AppleWakewordViewController.startRecordingAction(_:)),
                         for: .touchUpInside)
        button.setTitleColor(.blue, for: .normal)
        button.isEnabled = true
        return button
    }()
    
    var stopRecordingButton: UIButton = {
        let button: UIButton = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Stop", for: .normal)
        button.addTarget(self,
                         action: #selector(AppleWakewordViewController.stopRecordingAction(_:)),
                         for: .touchUpInside)
        button.setTitleColor(.blue, for: .normal)
        button.isEnabled = false
        return button
    }()
    
    var switchButton: UIButton = {
        let button: UIButton = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Switch Inputs", for: .normal)
        button.addTarget(self,
                         action: #selector(AppleWakewordViewController.switchInputs),
                         for: .touchUpInside)
        button.setTitleColor(.blue, for: .normal)
        button.isEnabled = true
        return button
    }()
    
    lazy public var pipeline: SpeechPipeline = {
        let c = SpeechConfiguration()
        c.tracing = Trace.Level.DEBUG
        return SpeechPipeline(SpeechProcessors.appleSpeech.processor,
                              speechConfiguration: c,
                              speechDelegate: self,
                              wakewordService: SpeechProcessors.appleWakeword.processor,
                              pipelineDelegate: self)
    }()
    
    override func loadView() {
        super.loadView()
        self.view.backgroundColor = .white
        self.title = "Apple Wakeword"
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(AppleWakewordViewController.dismissViewController(_:)))
        self.navigationItem.rightBarButtonItem = doneBarButtonItem
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.view.addSubview(self.startRecordingButton)
        self.view.addSubview(self.stopRecordingButton)
        self.view.addSubview(self.switchButton)
        
        self.startRecordingButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.startRecordingButton.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.startRecordingButton.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        
        self.stopRecordingButton.topAnchor.constraint(equalTo: self.startRecordingButton.bottomAnchor, constant: 50.0).isActive = true
        self.stopRecordingButton.leftAnchor.constraint(equalTo: self.startRecordingButton.leftAnchor).isActive = true
        self.stopRecordingButton.rightAnchor.constraint(equalTo: self.startRecordingButton.rightAnchor).isActive = true
        
        self.switchButton.topAnchor.constraint(equalTo: self.startRecordingButton.bottomAnchor, constant: 100.0).isActive = true
        self.switchButton.leftAnchor.constraint(equalTo: self.startRecordingButton.leftAnchor).isActive = true
        self.switchButton.rightAnchor.constraint(equalTo: self.startRecordingButton.rightAnchor).isActive = true
    }
    
    @objc func startRecordingAction(_ sender: Any) {
        if (!self.pipeline.context.isActive) {
            self.pipeline.start()
        }
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    @objc func stopRecordingAction(_ sender: Any) {
        self.pipeline.stop()
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    @objc func switchInputs() {
        let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.switchInputsIfAvailable()  
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

extension AppleWakewordViewController: SpeechEventListener, PipelineDelegate {

    func didTimeout() {
        print("timeout")
    }
    
    func didActivate() {
        print("didActivate")
        self.pipeline.activate()
    }
    
    func didDeactivate() {
        print("didDeactivate")
        self.pipeline.deactivate()
    }
    
    func failure(speechError: Error) {
        if !speechError.localizedDescription.starts(with: "The operation couldn’t be completed. (kAFAssistantErrorDomain error 216.)") {
            print("didError: " + speechError.localizedDescription)
        }
    }
    
    func didRecognize(_ result: SpeechContext) {
        print("didRecognize \(result.transcript)")
    }
    
    func didStart() {
        print("didStart")
    }
    
    func didInit() {
        print("didInit")
    }
    
    func didStop() {
        print("didStop")
    }
    
    func setupFailed(_ error: String) {
        print("audiocontroller setup failed: " + error)
    }
    
    func didTrace(_ trace: String) {
        print("didTrace: \(trace)")
    }
}

