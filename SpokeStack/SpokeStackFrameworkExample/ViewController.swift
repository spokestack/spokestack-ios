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

public struct GoogleConfiguration: GoogleRecognizerConfiguration {
    
    public var host: String {
        return "speech.googleapis.com"
    }
    
    public var apiKey: String {
        return "AIzaSyAX01kY6iygg04-dexAr-cR9ZdYSMemWL0"
    }
    
    public var enableWordTimeOffsets: Bool {
        return true
    }
    
    public var maxAlternatives: Int32 {
        return 30
    }
    
    public var singleUtterance: Bool {
        return false
    }
    
    public var interimResults: Bool {
        return true
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var startRecordingButton: UIButton!

    @IBOutlet weak var stopRecordingButton: UIButton!
    
    @IBOutlet weak var resultsLabel: UILabel!
    
    lazy private var pipeline: SpeechPipeline = {
        
        let configuration: GoogleConfiguration = GoogleConfiguration()
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
        print("didFinish")
        // Disable finish
    }
    
    func didStart() {
        print("didStart")
        // Disable start
    }
}

