//
//  ViewController.swift
//  SpokeStackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import UIKit
import SpokeStack
import AVFoundation

class GoogleViewController: UIViewController {
    
    lazy var startRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start Recording", for: .normal)
        button.addTarget(self,
                         action: #selector(GoogleViewController.startRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.blue, for: .normal)
        
        return button
    }()
    
    var stopRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Stop Recording", for: .normal)
        button.addTarget(self,
                         action: #selector(GoogleViewController.stopRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.blue, for: .normal)
        
        
        return button
    }()
    
    lazy private var pipeline: SpeechPipeline = {
        
        let googleConfiguration: GoogleRecognizerConfiguration = GoogleRecognizerConfiguration()
        googleConfiguration.apiKey = "REPLACE_ME"
        
        return try! SpeechPipeline(.googleSpeech,
                                   speechConfiguration: googleConfiguration,
                                   speechDelegate: self,
                                   wakewordService: .appleWakeword,
                                   wakewordConfiguration: WakewordConfiguration(),
                                   wakewordDelegate: self)
    }()
    
    override func loadView() {
        
        super.loadView()
        
        self.view.backgroundColor = .white
        self.title = "Google"
        
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(GoogleViewController.dismissViewController(_:)))
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
    }
    
    @objc func startRecordingAction(_ sender: Any) {
        self.pipeline.start()
    }
    
    @objc func stopRecordingAction(_ sender: Any) {
        self.pipeline.stop()
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

extension GoogleViewController: SpeechRecognizer, WakewordRecognizer {
    func timeout() {
        print("timeout")
    }
    
    func activate() {
        
    }
    
    func deactivate() {
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    func didError(_ error: Error) {
        print("didError \(String(describing: error))")
    }
    
    func didRecognize(_ result: SpeechContext) {
        print("transcript \(result.transcript)")
    }
    
    func didStart() {
        
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
}

