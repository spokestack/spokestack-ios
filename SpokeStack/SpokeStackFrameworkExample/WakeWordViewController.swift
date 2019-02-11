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

struct WKWordConfiguration: WakeRecognizerConfiguration {
    
    var wakeWords: String {
        return "up,dog"
    }
    
    var wakePhrases: String {
        return "up dog"
    }
    
    var frameWidth: Int {
        return 20
    }
    
    var wakeActionMin: Int {
        return 600
    }
    
    var wakeSmoothLength: Int {
        return 50
    }
    
    var wakePhraseLength: Int {
        return 2000
    }
    
    var preEmphasis: Float {
        return 0.97
    }
}

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
        
        let wakeConfiguration: WKWordConfiguration = WKWordConfiguration()
        
        return try! SpeechPipeline(.wakeword,
                                   configuration: wakeConfiguration,
                                   delegate: self)
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
        self.pipeline.start()
    }
    
    @objc func stopRecordingAction(_ sender: Any) {
        self.pipeline.stop()
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

extension WakeWordViewController: SpeechRecognizer {
    
    func didRecognize(_ result: SPSpeechContext) {
        print("transcript \(result.transcript)")
    }
    
    func didFinish(_ error: Error?) {

        print("didFinish \(String(describing: error))")
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    func didStart() {
        
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
}

