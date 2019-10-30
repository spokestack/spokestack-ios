//
//  AppleWakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/4/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

@objc public class AppleWakewordRecognizer: NSObject, SpeechProcessor {
    
    // MARK: public properties
    
    @objc public static let sharedInstance: AppleWakewordRecognizer = AppleWakewordRecognizer()
    public var configuration: SpeechConfiguration? = SpeechConfiguration() {
        didSet {
            if self.configuration != nil {
                // wakeword
                phrases = self.configuration!.wakePhrases.components(separatedBy: ",")
                // Tracing
                self.traceLevel = self.configuration!.tracing
                /// VAD
                do {
                    try self.vad.create(mode: self.configuration!.vadMode, delegate: self, frameWidth: self.configuration!.frameWidth, sampleRate: self.configuration!.sampleRate)
                } catch {
                    assertionFailure("AppleWakewordRecognizer failed to create a valid VAD")
                }
            }
        }
    }
    public weak var delegate: SpeechEventListener?
    public var context: SpeechContext = SpeechContext()
    
    // MARK: private properties
    
    private var phrases: Array<String> = []
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var dispatchWorker: DispatchWorkItem?
    private var vad: WebRTCVAD = WebRTCVAD()
    private var recognitionTaskRunning: Bool = false
    
    private var traceLevel: Trace.Level = Trace.Level.NONE
    
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
        Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "startStreaming", delegate: self.delegate, caller: self)
        self.context = context
        self.prepareAudioEngine()
        self.audioEngine.prepare()
        self.context.isStarted = true
    }
    
    public func stopStreaming(context: SpeechContext) {
        AudioController.sharedInstance.delegate = nil
        Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "stopStreaming", delegate: self.delegate, caller: self)
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
        Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "prepareAudioEngine", delegate: self.delegate, caller: self)
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
            Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "startRecognition", delegate: self.delegate, caller: self)
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask()
            self.recognitionTaskRunning = true
            
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
        Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "stopRecognition", delegate: self.delegate, caller: self)
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        self.recognitionTaskRunning = false
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
    }
    
    private func createRecognitionTask() throws -> Void {
        Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "createRecognitionTask", delegate: self.delegate, caller: self)

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
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.traceLevel, message: "resultHandler error \(nse.code.description)", delegate: strongSelf.delegate, caller: strongSelf)
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
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.traceLevel, message: "resultHandler error \(nse.code.description)", delegate: strongSelf.delegate, caller: strongSelf)
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
                    Trace.trace(Trace.Level.DEBUG, configLevel: strongSelf.traceLevel, message: "hears \(r.bestTranscription.formattedString)", delegate: strongSelf.delegate, caller: strongSelf)
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
                        strongSelf.context.isActive = true
                        delegate.activate()
                    }
                }
        })
    }
}

// MARK: AudioControllerDelegate implementation

extension AppleWakewordRecognizer: AudioControllerDelegate {
    func process(_ frame: Data) -> Void {
        /// multiplex the audio frame data to both the vad and, if activated, the model pipelines
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            do { try strongSelf.vad.process(frame: frame, isSpeech: false) }
            catch let error {
                strongSelf.delegate?.didError(error)
            }
        }
    }
}

// MARK: VADDelegate implementation

extension AppleWakewordRecognizer: VADDelegate {
    public func activate(frame: Data) {
        if (self.context.isActive || self.recognitionTaskRunning) {
            // asr is active, so don't interrupt
        } else if (self.context.isStarted){
            self.context.isSpeech = true
            do {
                Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "activate self.context.isActive: \(self.context.isActive)", delegate: self.delegate, caller: self)
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
            Trace.trace(Trace.Level.DEBUG, configLevel: self.traceLevel, message: "deactivate self.context.isActive: \(self.context.isActive)", delegate: self.delegate, caller: self)
            self.context.isSpeech = false
            self.stopRecognition()
            self.audioEngine.pause()
        }
    }
}
