//
//  ViewController.swift
//  SpokeStackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import UIKit
import SpokeStack
import googleapis
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var startRecordingButton: UIButton!

    @IBOutlet weak var stopRecordingButton: UIButton!
    
    @IBOutlet weak var resultsLabel: UILabel!
    
    lazy private var pipeline: SpeechPipeline = {
        
        let configuration: GoogleRecognizerConfiguration = GoogleRecognizerConfiguration()
        configuration.apiKey = "REPLACE_ME"
        return try! SpeechPipeline(.google,
                                   configuration: configuration,
                                   delegate: self)
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
    
    func didError(_ error: String) {
        self.resultsLabel.text = error
        self.stopRecordingButton.isEnabled.toggle()
        self.startRecordingButton.isEnabled.toggle()
    }
}

