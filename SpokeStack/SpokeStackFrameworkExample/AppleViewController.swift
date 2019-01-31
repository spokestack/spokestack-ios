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

struct AppleWordConfiguration: WakeRecognizerConfiguration {
    
    var wakeWords: String {
        return "up,dog"
    }
    
    var wakePhrases: String {
        return "up dog"
    }
}

class AppleViewController: UIViewController {
    
    @IBOutlet weak var startRecordingButton: UIButton!
    
    @IBOutlet weak var stopRecordingButton: UIButton!
    
    @IBOutlet weak var resultsLabel: UILabel!
    
    lazy private var pipeline: SpeechPipeline = {
        
        let wakeConfiguration: AppleWordConfiguration = AppleWordConfiguration()
        
        return try! SpeechPipeline(.wakeword,
                                   configuration: wakeConfiguration,
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

extension AppleViewController: SpeechRecognizer {
    
    func didRecognize(_ result: SPSpeechContext) {
//        self.resultsLabel.text = result.transcript
    }
    
    func didFinish(_ error: Error?) {
        print("didFinish \(String(describing: error))")
//        self.stopRecordingButton.isEnabled.toggle()
//        self.startRecordingButton.isEnabled.toggle()
    }
    
    func didStart() {
        
//        self.stopRecordingButton.isEnabled.toggle()
//        self.startRecordingButton.isEnabled.toggle()
    }
}

