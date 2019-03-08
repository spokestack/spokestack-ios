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
    public var configuration: WakewordConfiguration?
    public weak var delegate: WakewordRecognizer?
    
    // MARK: wakeword properties
    
    private var phrases: Array<String> = []
    
    // MARK: recognition properties
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var dispatchWorker: DispatchWorkItem?
    
    // MARK: NSObject methods
    
    deinit {
        print("AppleWakewordRecognizer deinit")
        speechRecognizer.delegate = nil
    }
    
    public override init() {
        super.init()
        print("AppleWakewordRecognizer init")
    }
    
    // MARK: SpeechRecognizerService implementation
    
    func startStreaming(context: SpeechContext) {
        print("AppleWakewordRecognizer startStreaming")
        do {
            phrases = configuration!.wakePhrases.components(separatedBy: ",")
            self.prepareAudioEngine()
            self.startRecognition(context: context)
            self.audioEngine.prepare()
            try audioEngine.start()
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    func stopStreaming(context: SpeechContext) {
        print("AppleWakewordRecognizer stopStreaming")
        self.stopRecognition()
        self.dispatchWorker?.cancel()
        self.dispatchWorker = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: private functions
    
    private func prepareAudioEngine() {
        print("AppleWakewordRecognizer prepareAudioEngine")
        let buffer: Int = (self.configuration!.sampleRate / 1000) * self.configuration!.frameWidth
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
    }
    
    private func startRecognition(context: SpeechContext) {
        print("AppleWakewordRecognizer startRecognition")
        do {
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask(context: context)
            
            // Automatically restart wakeword task if it goes over Apple's 1 minute listening limit
            self.dispatchWorker = DispatchWorkItem {[weak self] in
                print("AppleWakewordRecognizer dispatchWorker")
                self?.stopRecognition()
                self?.startRecognition(context: context)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakewordRequestTimeout), execute: self.dispatchWorker!)
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    private func stopRecognition() {
        print("AppleWakewordRecognizer stopRecognition")
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
    }
    
    private func createRecognitionTask(context: SpeechContext) throws -> Void {
        print("AppleWakewordRecognizer createRecognitionTask")
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: {[weak self] result, error in
                print("AppleWakewordRecognizer recognitionTask resultHandler")
                guard let strongSelf = self else {
                    print("AppleWakewordRecognizer recognitionTask resultHandler strongSelf is nil")
                    return
                }
                guard let delegate = strongSelf.delegate else {
                    print("AppleWakewordRecognizer recognitionTask resultHandler delegate is nil")
                    return
                }
                if let e = error {
                    if let nse: NSError = error as NSError? {
                        if nse.domain == "kAFAssistantErrorDomain" {
                            switch nse.code {
                            case 203: // request timed out, retry
                                strongSelf.stopRecognition()
                                strongSelf.startRecognition(context: context)
                                break
                            case 209: // ¯\_(ツ)_/¯
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                break
                            default:
                                delegate.didError(e)
                            }
                        }
                    } else {
                        delegate.didError(e)
                    }
                }
                if let r = result {
                    print("AppleWakewordRecognizer hears " + r.bestTranscription.formattedString)
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
                        print("AppleWakewordRecognizer wakeword detected")
                        delegate.activate()
                    }
                }
        })
    }
}
