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
        return "speech.google.com"
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
    
    func didWriteSteamingAudioContent(_ request: StreamingRecognizeRequest) {
    
        let dataCount = request.audioContent.count
        let bcf = ByteCountFormatter()
        
        bcf.countStyle = .file
        
        let string = bcf.string(fromByteCount: Int64(dataCount))
        print("did write more audio \(string)")
    }
    
    
    func didWriteInital(_ request: StreamingRecognizeRequest) {
        print("did write initial request \(request)")
    }
    
    func didFindResultsButNotFinal() {
        print("didFindResultsButNotFinal")
    }
    
    func didHaveConfiguration(_ configuration: RecognizerConfiguration) {
        let gconfig = configuration as! GoogleConfiguration
        print("what is my configuration \(gconfig.host)")
    }
    
    func streamingDidStart() {
        print("streaming did start")
    }
    
    func beginAnalyzing() {
        print("beingAnalyzing")
    }
    
    func didFindResults(_ result: String) {
        print("results found \(result)")
    }
    
    func setupFailed() {
        print("setup failed")
    }
    
    
    func didRecognize(_ result: SPSpeechContext) {
        print("result \(result)")
        self.resultsLabel.text = result.transcript
    }
    
    func didFinish() {
        print("didFinish")
    }
    
    func didStart() {
        print("didStart")
    }
}

