//
//  AppleWakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/4/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

public class AppleWakewordRecognizer: NSObject, SpeechProcessor {
    
    // MARK: public properties
    
    static let sharedInstance: AppleWakewordRecognizer = AppleWakewordRecognizer()
    public var configuration: SpeechConfiguration? = SpeechConfiguration() {
        didSet {
            if self.configuration != nil {
                phrases = self.configuration!.wakePhrases.components(separatedBy: ",")
            }
        }
    }
    public weak var delegate: SpeechEventListener?
    public var context: SpeechContext = SpeechContext()
    
    // MARK: wakeword properties
    
    private var phrases: Array<String> = []
    
    // MARK: recognition properties
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var dispatchWorker: DispatchWorkItem?
    private var vad: WebRTCVAD = WebRTCVAD()
    
    // MARK: NSObject methods
    
    deinit {
        self.speechRecognizer.delegate = nil
    }
    
    public override init() {
        super.init()
    }
    
    // MARK: SpeechRecognizerService implementation
    
    public func startStreaming(context: SpeechContext) {
        AudioController.sharedInstance.delegate = self
        self.context = context
        self.prepareAudioEngine()
        self.audioEngine.prepare()
        self.context.isStarted = true
    }
    
    public func stopStreaming(context: SpeechContext) {
        AudioController.sharedInstance.delegate = nil
        self.context = context
        self.stopRecognition()
        self.dispatchWorker?.cancel()
        self.dispatchWorker = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.context.isStarted = false
    }
    
    // MARK: private functions
    
    private func prepareAudioEngine() {
        
        do {
            try self.vad.create(mode: .HighQuality,
                                delegate: self,
                                frameWidth: self.configuration!.frameWidth,
                                sampleRate: self.configuration!.sampleRate)
        } catch {
            assertionFailure("AppleWakewordRecognizer failed to create a valid VAD")
        }
        
        let buffer: Int = (self.configuration!.sampleRate / 1000) * self.configuration!.frameWidth
        self.audioEngine.inputNode.removeTap(onBus: 0) // a belt-and-suspenders approach to fixing https://github.com/wenkesj/react-native-voice/issues/46
        self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(buffer),
            format: nil)
        {[weak self] buffer, when in
            guard let strongSelf = self else {
                return
            }
            strongSelf.recognitionRequest?.append(buffer)
        }
    }
    
    private func startRecognition() {
        do {
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask()
            
            // Automatically restart wakeword task if it goes over Apple's 1 minute listening limit
            self.dispatchWorker = DispatchWorkItem {[weak self] in
                self?.stopRecognition()
                self?.startRecognition()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakewordRequestTimeout), execute: self.dispatchWorker!)
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    private func stopRecognition() {
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
    }
    
    private func createRecognitionTask() throws -> Void {
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: {[weak self] result, error in
                guard let strongSelf = self else {
                    assertionFailure("AppleWakewordRecognizer recognitionTask resultHandler strongSelf is nil")
                    return
                }
                guard let delegate = strongSelf.delegate else {
                    assertionFailure("AppleWakewordRecognizer recognitionTask resultHandler strongSelf delegate is nil")
                    return
                }
                if let e = error {
                    if let nse: NSError = error as NSError? {
                        if nse.domain == "kAFAssistantErrorDomain" {
                            switch nse.code {
                            case 0..<200: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "resultHandler error \(nse.code.description)", delegate: strongSelf.delegate, caller: strongSelf)
                                break
                            case 203: // request timed out, retry
                                strongSelf.stopRecognition()
                                strongSelf.startRecognition()
                                break
                            case 209: // ¯\_(ツ)_/¯
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                break
                            case 300..<603: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "resultHandler error \(nse.code.description)", delegate: strongSelf.delegate, caller: strongSelf)
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
                    Trace.trace(Trace.Level.DEBUG, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "hears \(r.bestTranscription.formattedString)", delegate: strongSelf.delegate, caller: strongSelf)
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
                        delegate.activate()
                    }
                }
        })
    }
}

extension AppleWakewordRecognizer: AudioControllerDelegate {
    func process(_ frame: Data) -> Void {
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            do { try strongSelf.vad.process(frame: frame, isSpeech: true) }
            catch let error {
                strongSelf.delegate?.didError(error)
            }
        }
    }
}

extension AppleWakewordRecognizer: VADDelegate {
    public func activate(frame: Data) {
        if (self.context.isActive) {
            // asr is active, so don't interrupt
        } else if (self.context.isStarted){
            do {
                try self.audioEngine.start()
                self.startRecognition()
            } catch let error {
                self.delegate?.didError(error)
            }
        }
    }
    
    public func deactivate() {
        if (self.context.isActive) {
            // asr is active, so don't interrupt
        } else {
            self.stopRecognition()
            self.audioEngine.pause()
        }
    }
}
