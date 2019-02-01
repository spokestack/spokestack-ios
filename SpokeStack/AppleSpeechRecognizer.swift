//
//  AppleSpeechRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 1/22/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

public class AppleSpeechRecognizer: SpeechRecognizerService {
    
let audioEngine = AVAudioEngine()
    let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    let request = SFSpeechAudioBufferRecognitionRequest()
    var recognitionTask: SFSpeechRecognitionTask? // or SFSpeechURLRecognitionRequest?
    private var audioData: NSMutableData!
    var configuration: RecognizerConfiguration
    private var streaming: Bool = false

    public weak var delegate: SpeechRecognizer?

    // MARK: Initializers
    
    public init() {
        AudioController.shared.delegate = self
    }
    
    // MARK: SpeechRecognizerService
    
    func startStreaming() {
        self.audioData = NSMutableData()
        AudioController.shared.startStreaming()
        self.delegate?.didStart()
    }
    
    func stopStreaming() {
        AudioController.shared.stopStreaming()
        if !self.streaming {
            return
        }
        self.streaming = false
    }
}

extension AppleSpeechRecognizer: AudioControllerDelegate {
    
    // MARK: AudioControllerDelegate implementation
    
    func setupFailed(_ error: String) {
        <#code#>
    }
    
    func processSampleData(_ data: Data) {
        guard case self.speechRecognizer = SFSpeechRecognizer() else {
            return
        }
        if (!speechRecognizer!.isAvailable) {
            return
        }
        self.streaming = true
        recognitionTask = self.speechRecognizer?.recognitionTask(with: self.request, resultHandler: { (result, error) in
            let context: SPSpeechContext = SPSpeechContext(transcript: result?.bestTranscription.formattedString ?? "unavailable",
                                                           // this is weird:
                                                           confidence: result?.transcriptions.first?.segments.sorted(by: { (a, b) -> Bool in
                                                            a.confidence <= b.confidence
                                                           }).first?.confidence ?? 0.0)
            self.delegate?.didRecognize(context)
            self.delegate?.didFinish()
            self.stopStreaming()
        })
    }
}
