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
    
    /// Configuration for the recognizer.
    @objc public var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    @objc public var context: SpeechContext
    
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
    
    public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
    }
    
    // MARK: SpeechProcessor implementation
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    @objc public func startStreaming() {
        self.activate()
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    @objc public func stopStreaming() {
        self.deactivate()
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    @objc public func process(_ frame: Data) {
        if self.context.isActive {
            if !self.active {
                self.activate()
            }
        } else if self.active {
            self.deactivate()
        }
    }
    
    // MARK: Private functions
    
    private func activate() {
        do {
            self.active = true
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            self.prepareAudioEngine()
            self.audioEngine.prepare()
            try self.audioEngine.start()
            try self.createRecognitionTask()
            self.wakeActiveMaxWorker = DispatchWorkItem {[weak self] in
                self?.configuration.delegateDispatchQueue.async {
                    self?.context.listeners.forEach { listener in
                        listener.didTimeout()
                        self?.deactivate()
                    }
                }
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(self.configuration.wakeActiveMax), execute: self.wakeActiveMaxWorker!)
        } catch let error {
            self.configuration.delegateDispatchQueue.async {
                self.context.listeners.forEach { listener in
                    listener.failure(speechError: error)
                }
            }
        }
    }
    
    private func prepareAudioEngine() {
        let bufferSize: Int = (self.configuration.sampleRate / 1000) * self.configuration.frameWidth
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
    
    private func deactivate() {
        self.active = false
        self.context.isActive = false
        self.recognitionTask?.finish()
        self.recognitionRequest?.endAudio()
        self.wakeActiveMaxWorker?.cancel()
        self.configuration.delegateDispatchQueue.async {
            self.context.listeners.forEach({ listener in
                listener.didDeactivate()
            })
        }
    }
    
    private func createRecognitionTask() throws -> Void {
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: { [weak self] result, error in
                guard let strongSelf = self else {
                    // the callback has been orphaned by stopStreaming, so just end things here.
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
                                Trace.trace(Trace.Level.INFO, message: "resultHandler error 203", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
                                strongSelf.deactivate()
                                break
                            case 209: // ¯\_(ツ)_/¯
                                Trace.trace(Trace.Level.INFO, message: "resultHandler error 209", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                Trace.trace(Trace.Level.INFO, message: "resultHandler error 216", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
                                
                                break
                            case 300..<603: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                break
                            default:
                                strongSelf.context.listeners.forEach({ listener in
                                    listener.failure(speechError: e)
                                })
                            }
                        }
                    } else {
                        strongSelf.context.listeners.forEach({ listener in
                            listener.failure(speechError: e)
                        })
                    }
                }
                if let r = result {
                    Trace.trace(Trace.Level.DEBUG, message: "recognized \(r.bestTranscription.formattedString)", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
                    strongSelf.wakeActiveMaxWorker?.cancel()
                    let confidence = r.transcriptions.first?.segments.sorted(
                        by: { (a, b) -> Bool in
                            a.confidence <= b.confidence }).first?.confidence ?? 0.0
                    strongSelf.context.transcript = r.bestTranscription.formattedString
                    strongSelf.context.confidence = confidence
                    strongSelf.configuration.delegateDispatchQueue.async {
                        strongSelf.context.listeners.forEach({ listener in
                            listener.didRecognize(strongSelf.context)
                        })
                    }
                    strongSelf.vadFallWorker = DispatchWorkItem {[weak self] in
                        self?.deactivate()
                    }
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration.vadFallDelay), execute: strongSelf.vadFallWorker!)
                }
            }
        )
    }
}
