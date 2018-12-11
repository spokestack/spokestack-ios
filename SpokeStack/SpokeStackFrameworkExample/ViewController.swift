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

struct GoogleConfiguration: GoogleRecognizerConfiguration {
    
    var apiKey: String {
        return "REPLACE_ME"
    }
}

struct WKWordConfiguration: WakeRecognizerConfiguration {
    
    var wakeWords: String {
        return "up, dog, break, yo, self, fool"
    }
    
    var wakePhrases: String {
        return "up dog, break yo self fool"
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var startRecordingButton: UIButton!

    @IBOutlet weak var stopRecordingButton: UIButton!
    
    @IBOutlet weak var resultsLabel: UILabel!
    
    lazy private var pipeline: SpeechPipeline = {
        
        let configuration: GoogleConfiguration = GoogleConfiguration()
        let wakeConfiguration: WKWordConfiguration = WKWordConfiguration()
        
        return try! SpeechPipeline(.google,
                                   configuration: configuration,
                                   delegate: self,
                                   wakeWordConfig: wakeConfiguration)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func startRecordingAction(_ sender: Any) {
        self.pipeline.start()
    }
    
    @IBAction func stopRecordingAction(_ sender: Any) {
        self.pipeline.stop()
    }
}

extension ViewController: SpeechRecognizer {
    
    func didRecognize(_ result: SPSpeechContext) {
        self.resultsLabel.text = result.transcript
    }
    
    func didFinish() {
        
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
    
    func didStart() {
        
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
}

