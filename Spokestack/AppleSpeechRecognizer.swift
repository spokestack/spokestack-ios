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
@objc public class AppleSpeechRecognizer: NSObject {
    
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
    private var isActive = false
    
    // MARK: NSObject implementation
    
    deinit {
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        speechRecognizer.delegate = nil
    }
    
    /// Initializes a AppleSpeechRecognizer instance.
    ///
    /// A recognizer is initialized by, and receives `startStreaming` and `stopStreaming` events from, an instance of `SpeechPipeline`.
    ///
    /// The AppleSpeechRecognizer receives audio data frames to `process` from a tap into the system `AudioEngine`.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
    }
    
    // MARK: Private functions
    
    private func prepare() {
        self.audioEngine.inputNode.removeTap(onBus: 0) // a belt-and-suspenders approach to fixing https://github.com/wenkesj/react-native-voice/issues/46
        self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(self.configuration.audioEngineBufferSize),
            format: self.audioEngine.inputNode.inputFormat(forBus: 0))
        {[weak self] buffer, when in
            guard let strongSelf = self else {
                return
            }
            strongSelf.recognitionRequest?.append(buffer)
        }
        self.audioEngine.prepare()
        self.wakeActiveMaxWorker = DispatchWorkItem {[weak self] in
            self?.context.dispatch(.timeout)
            self?.deactivate()
        }
    }
    
    private func activate() {
        do {
            // Accessing debug information is costly and we don't want to do it unnecessarily, so make a duplicate level check beforehand.
            if self.configuration.tracing.rawValue <= Trace.Level.DEBUG.rawValue {
                Trace.trace(.DEBUG, message: "inputSampleRate: \(self.audioEngine.inputNode.inputFormat(forBus: 0).sampleRate) inputChannels: \(self.audioEngine.inputNode.inputFormat(forBus: 0).channelCount) bufferSize \(self.configuration.audioEngineBufferSize)", config: self.configuration, context: self.context, caller: self) }
            try self.audioEngine.start()
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask()
            self.isActive = true
            
            // Automatically end recognition task if it goes over the activiation max
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(self.configuration.wakeActiveMax), execute: self.wakeActiveMaxWorker!)
        } catch let error {
            self.context.error = error
            self.context.dispatch(.error)
        }
    }
    
    private func deactivate() {
        if self.isActive {
            self.isActive = false
            self.context.isActive = false
            self.vadFallWorker?.cancel()
            self.wakeActiveMaxWorker?.cancel()
            self.recognitionTask?.finish()
            self.recognitionTask = nil
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
            self.audioEngine.stop()
            self.context.dispatch(.deactivate)
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
                if !strongSelf.isActive {
                    return
                }
                strongSelf.vadFallWorker?.cancel()
                strongSelf.vadFallWorker = nil
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
                                strongSelf.context.error = e
                                strongSelf.context.dispatch(.error)
                            }
                        }
                    } else {
                        strongSelf.context.error = e
                        strongSelf.context.dispatch(.error)
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
                    strongSelf.vadFallWorker = DispatchWorkItem {[weak self] in
                        self?.context.dispatch(.recognize)
                        self?.deactivate()
                    }
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(strongSelf.configuration.vadFallDelay), execute: strongSelf.vadFallWorker!)
                }
            }
        )
    }
}

extension AppleSpeechRecognizer: SpeechProcessor {
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    @objc public func startStreaming() {
    }

    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    @objc public func stopStreaming() {
        if self.isActive {
            self.deactivate()
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
        }
    }

    /// Processes an audio frame, recognizing speech.
    /// - Note: Processes audio in an async thread.
    /// - Remark: The Apple ASR hooks up directly to its own audio tap for processing audio frames. When the `AudioController` calls this `process`, it checks to see if the pipeline is activated, and if so kicks off its own VAD and ASR independently of any other components in the speech pipeline.
    /// - Parameter frame: Audio frame of samples.
    @objc public func process(_ frame: Data) {
        if self.context.isActive {
            if !self.isActive {
                self.prepare()
                self.activate()
            }
        } else if self.isActive {
            self.deactivate()
        }
    }
}
