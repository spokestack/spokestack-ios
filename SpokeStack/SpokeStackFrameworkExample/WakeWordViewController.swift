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

class WakeWordViewController: UIViewController {
    
    lazy var startRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start Recording", for: .normal)
        button.addTarget(self,
                         action: #selector(WakeWordViewController.startRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.blue, for: .normal)
        
        return button
    }()
    
    var stopRecordingButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Stop Recording", for: .normal)
        button.addTarget(self,
                         action: #selector(WakeWordViewController.stopRecordingAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.blue, for: .normal)
        
        
        return button
    }()

    lazy private var pipeline: SpeechPipeline = {
        
        let wakeConfiguration: WakewordConfiguration = WakewordConfiguration()
        
        wakeConfiguration.preEmphasis = 0.97
        wakeConfiguration.wakePhraseLength = 2000
        wakeConfiguration.wakeSmoothLength = 50
        wakeConfiguration.wakeActiveMin = 600
        wakeConfiguration.frameWidth = 20
        wakeConfiguration.wakeWords = "up,dog"

        return try! SpeechPipeline(.appleSpeech,
                                   speechConfiguration: RecognizerConfiguration(),
                                   speechDelegate: self,
                                   wakewordService: .wakeword,
                                   wakewordConfiguration: wakeConfiguration,
                                   wakewordDelegate: self)
    }()
    
    override func loadView() {
        
        super.loadView()
        self.view.backgroundColor = .white
        self.title = "WakeWord"
        
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(WakeWordViewController.dismissViewController(_:)))
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
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

extension WakeWordViewController: SpeechRecognizer, WakewordRecognizer {
    
    func activate() {
        print("activate *******")
        self.pipeline.activate()
    }
    
    func deactivate() {
        print("deactivate")
    }
    
    func didError(_ error: Error) {
        if !error.localizedDescription.starts(with: "The operation couldn’t be completed. (kAFAssistantErrorDomain error 216.)") {
            print("didError: " + error.localizedDescription)
        }
    }
    
    func didRecognize(_ result: SpeechContext) {
        print("didRecognize \(result.transcript)")
    }
    
    func didFinish() {
        print("didFinish")
        if (!self.pipeline.context.isActive) {
            self.pipeline.start()
        } else {
            self.pipeline.activate()
        }
    }
    
    func didStart() {
        print("didStart")
    }
}
