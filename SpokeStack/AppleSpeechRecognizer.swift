//
//  AppleSpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 1/10/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

class AppleSpeechRecognizer: NSObject, SpeechRecognizerService {
    
    // MARK: Public (properties)
    
    static let sharedInstance: AppleSpeechRecognizer = AppleSpeechRecognizer()
    
    var configuration: RecognizerConfiguration = RecognizerConfiguration()
    private var wakewordConfiguration: WakewordRecognizerConfiguration = WakewordRecognizerConfiguration()
    
    weak var delegate: SpeechRecognizer?
    
    // MARK: Private (properties)
    
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    
    // MARK: Initializers
    
    deinit {
        speechRecognizer.delegate = nil
    }
    
    override init() {
        super.init()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch let error {
            print("audioSession properties weren't set because of an error. \(error)")
        }
    }
    
    // MARK: SpeechRecognizerService
    
    func startStreaming() {
        
        self.prepareAudio()
        self.startAudioEngine()
    }
    
    func stopStreaming() {
     
        /// Stop the audio engine and tear down
        
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        speechRecognizer.delegate = nil
        audioEngine.stop()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func prepareAudio() -> Void {
        
        /// Speech Recognizer
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode: AVAudioInputNode = self.audioEngine.inputNode
        
        guard let recognitionRequest = self.recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        let phrases: Array<String> = self.wakewordConfiguration.wakePhrases.components(separatedBy: ",")

        self.recognitionTask = self.speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: {[weak self] result, error in
            
            guard let strongSelf = self else {
                return
            }
            
            var isFinal: Bool = false
            
            if result != nil {
                
                let foundResult: Bool = !phrases.filter({
                    result!.bestTranscription.formattedString.lowercased().contains($0.lowercased())
                }).isEmpty
                
                print("returned \(String(describing: result))")
                
                if foundResult {
                    
                    strongSelf.recognitionTask?.cancel()
                    print("found it \(String(describing: result?.bestTranscription.formattedString))")
                    isFinal = true
                    
                    let finalTranscript: SFTranscription = result!.bestTranscription
                    let confidence: Float = finalTranscript.segments.last?.confidence ?? 0.0
                    let context: SPSpeechContext = SPSpeechContext(transcript: finalTranscript.formattedString, confidence: confidence)
    
                    strongSelf.delegate?.didRecognize(context)
                    strongSelf.delegate?.didFinish()
                }
            }
            
            if error != nil || isFinal {
                
                strongSelf.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                strongSelf.stopStreaming()
            }
        })
        
        let buffer: Int = (self.wakewordConfiguration.sampleRate / 1000) * self.wakewordConfiguration.frameWidth
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(buffer), format: recordingFormat) {[weak self] buffer, when in
            
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.recognitionRequest?.append(buffer)
        }
        
        self.audioEngine.prepare()
    }
    
    private func startAudioEngine() -> Void {

        do {
            
            try audioEngine.start()
            
        } catch {
            
            print("audioEngine couldn't start because of an error.")
        }
    }
}
