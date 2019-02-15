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
    
    weak var delegate: SpeechRecognizer?
    
    // MARK: Private (properties)
    
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    
    private var dispatchWorker: DispatchWorkItem?
    
    // MARK: initializers
    
    deinit {
        speechRecognizer.delegate = nil
    }
    
    override init() {
        super.init()
    }
    
    // MARK: SpeechRecognizerService implementation
    
    func startStreaming(context: SpeechContext) {
        
        self.setup()
        
        do {
        
            try self.prepareRecognition(context: context)
            self.audioEngine.prepare()
            
            try self.audioEngine.start()
            context.isActive = true

        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    func stopStreaming(context: SpeechContext) {
        
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        
        self.recognitionTask?.cancel()
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.recognitionTask = nil
     
        context.isActive = false
    }
    
    // MARK: Private (methods)
    
    private func setup() -> Void {
        
        do {
            
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    private func prepareRecognition(context: SpeechContext) throws -> Void {
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = self.recognitionRequest else {
            throw SpeechRecognizerError.unknownCause("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // MARK: AVAudioEngine
        
        let buffer: Int = (self.configuration.sampleRate / 1000) * self.configuration.frameWidth
        let recordingFormat = self.audioEngine.inputNode.outputFormat(forBus: 0)
        
        self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(buffer),
            format: recordingFormat) {[weak self] buffer, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.recognitionRequest?.append(buffer)
        }
        
        // MARK: recognitionTask
        
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest,
            resultHandler: {[weak self] result, error in
                
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.dispatchWorker?.cancel()
                
                if let e = error {
                    strongSelf.delegate?.didError(e)
                    //strongSelf.stopStreaming(context: context)
                }
                
                if let r = result {
                    print("what is the ASR result \(r.bestTranscription.formattedString)")
                    let confidence = r.spstk_confidence
                    context.transcript = r.bestTranscription.formattedString
                    context.confidence = confidence
                    
                    strongSelf.dispatchWorker = DispatchWorkItem {
                        strongSelf.delegate?.didRecognize(context)
                        strongSelf.stopStreaming(context: context)
                        strongSelf.delegate?.didFinish()
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration.vadFallDelay),
                                                  execute: strongSelf.dispatchWorker!)
                }
        })
    }
}
