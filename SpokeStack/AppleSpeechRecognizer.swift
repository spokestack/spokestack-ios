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
    
    // MARK: public properties
    
    static let sharedInstance: AppleSpeechRecognizer = AppleSpeechRecognizer()
    var configuration: RecognizerConfiguration = RecognizerConfiguration()
    weak var delegate: SpeechRecognizer?
    
    // MARK: private properties
    
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var dispatchWorker: DispatchWorkItem?
    
    // MARK: NSObject methods
    
    deinit {
        speechRecognizer.delegate = nil
        recognitionRequest = nil
    }
    
    override init() {
        super.init()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
    }
    
    // MARK: SpeechRecognizerService implementation
    
    func startStreaming(context: SpeechContext) {
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
        self.recognitionTask = nil
        context.isActive = false
    }
    
    // MARK: private functions
    
    private func prepareRecognition(context: SpeechContext) throws -> Void {
        
        // MARK: AVAudioEngine
        let buffer: Int = (self.configuration.sampleRate / 1000) * self.configuration.frameWidth
        let recordingFormat = self.audioEngine.inputNode.outputFormat(forBus: 0)
        self.audioEngine.inputNode.removeTap(onBus: 0) // a belt-and-suspenders approach to fixing https://github.com/wenkesj/react-native-voice/issues/46
        self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(buffer),
            format: recordingFormat)
        {[weak self] buffer, when in
            guard let strongSelf = self else {
                return
            }
            strongSelf.recognitionRequest?.append(buffer)
        }
        
        // MARK: recognitionTask
        
        if (self.recognitionTask == nil) {
            self.recognitionTask = self.speechRecognizer.recognitionTask(
                with: recognitionRequest!,
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
                        let confidence = r.transcriptions.first?.segments.sorted(
                            by: { (a, b) -> Bool in
                                a.confidence <= b.confidence }).first?.confidence ?? 0.0
                        context.transcript = r.bestTranscription.formattedString
                        context.confidence = confidence
                        strongSelf.dispatchWorker = DispatchWorkItem {[weak self] in
                            self?.delegate?.didRecognize(context)
                            self?.stopStreaming(context: context)
                            self?.delegate?.didFinish()
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration.vadFallDelay), execute: strongSelf.dispatchWorker!)
                    }
            })
        }
    }
}
