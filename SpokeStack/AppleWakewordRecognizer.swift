//
//  AppleWakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/4/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

public class AppleWakewordRecognizer: NSObject, WakewordRecognizerService {

    // MARK: public properties
    
    static let sharedInstance: AppleWakewordRecognizer = AppleWakewordRecognizer()
    public var configuration: WakewordConfiguration = WakewordConfiguration()
    public weak var delegate: WakewordRecognizer?
    
    // MARK: wakeword properties
    
    private var phrases: Array<String> = []
    
    // MARK: recognition properties
    
    private let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    
    // MARK: NSObject implementations
    
    deinit {
        speechRecognizer.delegate = nil
    }
    
    public override init() {
        super.init()
        phrases = self.configuration.wakePhrases.components(separatedBy: ",")
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    // MARK: SpeechRecognizerService implementation
    
    func startStreaming(context: SpeechContext) {
        do {
            context.isActive = true
            try self.prepareRecognition(context: context)
            audioEngine.prepare()
            try audioEngine.start()
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    func stopStreaming(context: SpeechContext) {
        audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: private functions
    
    private func prepareRecognition(context: SpeechContext) throws -> Void {

        // MARK: recognitionRequest

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
            format: recordingFormat)
        {[weak self] buffer, when in
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
            if let e = error {
                /*
                 A `Error Domain=kAFAssistantErrorDomain Code=216 "(null)"` (although sometimes it’s a `209` instead of `216`) happens in this `recognitionTask` callback that occurs _after_ `stopStreaming`. I’ve verified that `stopStreaming` does everything it’s supposed to in the order it’s supposed to. The error doesn’t seem to affect anything (and other people report the same https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                 */
                strongSelf.delegate?.didError(e)
            }
            if let r = result {
                let wakewordDetected: Bool =
                    !strongSelf.phrases
                        .filter({
                            r
                                .bestTranscription
                                .formattedString
                                .lowercased()
                                .contains($0.lowercased())})
                        .isEmpty
                if wakewordDetected {
                    strongSelf.stopStreaming(context: context)
                    strongSelf.delegate?.activate()
                }
            }
        })
    }
}
