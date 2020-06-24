//
//  AppleSpeechRecognizer.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 1/10/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import Speech

/**
 This pipeline component uses the Apple `SFSpeech` API to stream audio samples for speech recognition.
 
 Once speech pipeline coordination via `startStreaming` is received, the recognizer begins streaming buffered frames to the Apple ASR API for recognition. Once speech pipeline coordination via `stopStreaming` is received, or when the Apple ASR API indicates a completed speech event, the recognizer completes the API request and calls the `SpeechEventListener` delegate's `didRecognize` event with the updated global speech context (including the audio transcript and confidence).
 */
@objc public class AppleSpeechRecognizer: NSObject, SpeechProcessor {

    // MARK: Public properties
    
    /// Singleton instance.
    @objc public static let sharedInstance: AppleSpeechRecognizer = AppleSpeechRecognizer()
    /// Configuration for the recognizer.
    @objc public var configuration: SpeechConfiguration?
    /// Delegate which receives speech pipeline control events.
    @objc public weak var delegate: SpeechEventListener?
    /// Global state for the speech pipeline.
    @objc public var context: SpeechContext?
    
    // MARK: Private properties

    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var vadFallWorker: DispatchWorkItem?
    private var wakeActiveMaxWorker: DispatchWorkItem?
    private var active = false
    
    // MARK: NSObject implementation
    
    deinit {
        speechRecognizer.delegate = nil
    }
    
    override init() {
        super.init()
    }
    
    // MARK: SpeechProcessor implementation
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    /// - Parameter context: The current speech context.
    @objc public func startStreaming(context: SpeechContext) {
        self.context = context
        self.prepareAudioEngine()
        self.audioEngine.prepare()
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest?.shouldReportPartialResults = true
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    /// - Parameter context: The current speech context.
    @objc public func stopStreaming(context: SpeechContext) {
        self.context = context
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.vadFallWorker?.cancel()
        self.wakeActiveMaxWorker?.cancel()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    @objc public func process(_ frame: Data) {
        guard let context = self.context else { return }
        if context.isActive {
            if !self.active {
                do {
                    self.active = true
                    try self.audioEngine.start()
                    try self.createRecognitionTask()
                    self.wakeActiveMaxWorker = DispatchWorkItem {[weak self] in
                        self?.active = false
                        self?.configuration?.delegateDispatchQueue.async {
                            self?.delegate?.didTimeout()
                            self?.delegate?.didDeactivate()
                        }
                    }
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakeActiveMax), execute: self.wakeActiveMaxWorker!)
                } catch let error {
                    self.configuration?.delegateDispatchQueue.async {
                        self.delegate?.failure(speechError: error)
                    }
                }
            }
        } else {
            self.active = false
            self.recognitionTask?.cancel()
            self.recognitionRequest?.endAudio()
            self.wakeActiveMaxWorker?.cancel()
        }
    }
    
    // MARK: Private functions
    
    private func prepareAudioEngine() {
        let bufferSize: Int = (self.configuration!.sampleRate / 1000) * self.configuration!.frameWidth
        self.audioEngine.inputNode.removeTap(onBus: 0) // a belt-and-suspenders approach to fixing https://github.com/wenkesj/react-native-voice/issues/46
        self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(bufferSize),
            format: nil)
        {[weak self] buffer, when in
            guard let strongSelf = self else {
                return
            }
            strongSelf.recognitionRequest?.append(buffer)
        }
    }
    
    private func createRecognitionTask() throws -> Void {
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: { [weak self] result, error in
                guard
                    let strongSelf = self,
                    let cntxt = strongSelf.context
                    else {
                    assertionFailure("AppleSpeechRecognizer recognitionTask resultHandler strongSelf is nil")
                    return
                }
                guard let _ = strongSelf.recognitionTask else {
                    // this task has been cancelled and set to nil by `stopStreaming`, so just end things here.
                    return
                }
                guard let delegate = strongSelf.delegate else {
                    assertionFailure("AppleSpeechRecognizer recognitionTask resultHandler delegate is nil")
                    return
                }
                strongSelf.vadFallWorker?.cancel()
                if let e = error {
                    if let nse: NSError = error as NSError? {
                        if nse.domain == "kAFAssistantErrorDomain" {
                            switch nse.code {
                            case 0..<200: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                break
                            case 203: // request timed out, retry
                                Trace.trace(Trace.Level.INFO, config: strongSelf.configuration, message: "resultHandler error 203", delegate: strongSelf.delegate, caller: strongSelf)
                                cntxt.isActive = false
                                strongSelf.configuration?.delegateDispatchQueue.async {
                                    delegate.didDeactivate()
                                }
                                break
                            case 209: // ¯\_(ツ)_/¯
                                Trace.trace(Trace.Level.INFO, config: strongSelf.configuration, message: "resultHandler error 209", delegate: strongSelf.delegate, caller: strongSelf)
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                Trace.trace(Trace.Level.INFO, config: strongSelf.configuration, message: "resultHandler error 216", delegate: strongSelf.delegate, caller: strongSelf)

                                break
                            case 300..<603: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                break
                            default:
                                delegate.failure(speechError: e)
                            }
                        }
                    } else {
                        delegate.failure(speechError: e)
                    }
                }
                if let r = result {
                    Trace.trace(Trace.Level.DEBUG, config: strongSelf.configuration, message: "recognized \(r.bestTranscription.formattedString)", delegate: strongSelf.delegate, caller: strongSelf)
                    strongSelf.wakeActiveMaxWorker?.cancel()
                    let confidence = r.transcriptions.first?.segments.sorted(
                        by: { (a, b) -> Bool in
                            a.confidence <= b.confidence }).first?.confidence ?? 0.0
                    cntxt.transcript = r.bestTranscription.formattedString
                    cntxt.confidence = confidence
                    strongSelf.vadFallWorker = DispatchWorkItem {[weak self] in
                        cntxt.isActive = false
                        strongSelf.active = false
                        strongSelf.configuration?.delegateDispatchQueue.async {
                            self?.delegate?.didRecognize(cntxt)
                            self?.delegate?.didDeactivate()
                        }
                    }
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration!.vadFallDelay), execute: strongSelf.vadFallWorker!)
                }
            }
        )
    }
}
