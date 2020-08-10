//
//  AppleWakewordRecognizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/4/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import Speech

/**
This pipeline component uses the Apple `SFSpeech` API to stream audio samples for wakeword recognition.

 Once speech pipeline coordination via `startStreaming` is received, the recognizer begins streaming buffered frames to the Apple ASR API for recognition. Upon wakeword or wakephrase recognition, the pipeline activation event is triggered and the recognizer completes the API request and awaits another coordination event. Once speech pipeline coordination via `stopStreaming` is received, the recognizer completes the API request and awaits another coordination event.
*/
@objc public class AppleWakewordRecognizer: NSObject {
    
    // MARK: Public properties
    
    /// Configuration for the recognizer.
    public var configuration: SpeechConfiguration

    /// Global state for the speech pipeline.
    public var context: SpeechContext
    
    // MARK: Private properties
    
    private var phrases: Array<String> = []
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var dispatchWorker: DispatchWorkItem?
    private var recognitionTaskRunning: Bool = false
    private var traceLevel: Trace.Level = Trace.Level.NONE
    
    // MARK: NSObject methods
    
    deinit {
        self.speechRecognizer.delegate = nil
    }
    
    public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
        self.configure()
    }
    
    private func configure() {
        // wakeword
        phrases = self.configuration.wakewords.components(separatedBy: ",")
        // Tracing
        self.traceLevel = self.configuration.tracing
    }
    
    // MARK: Private functions
    
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
    
    private func startRecognition() {
        do {
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask()
            self.recognitionTaskRunning = true
            
            // Automatically restart wakeword task if it goes over Apple's 1 minute listening limit
            self.dispatchWorker = DispatchWorkItem {[weak self] in
                self?.stopRecognition()
                self?.startRecognition()
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(self.configuration.wakewordRequestTimeout), execute: self.dispatchWorker!)
        } catch let error {
            self.context.error = error
            self.context.dispatch(.error)
        }
    }
    
    private func stopRecognition() {
        self.recognitionTask?.cancel()
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        self.recognitionTaskRunning = false
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
    }
    
    private func createRecognitionTask() throws -> Void {
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: {[weak self] result, error in
                guard let strongSelf = self else {
                    // the callback has been orphaned by stopStreaming, so just end things here.
                    return
                }
                if let e = error {
                    if let nse: NSError = error as NSError? {
                        if nse.domain == "kAFAssistantErrorDomain" {
                            switch nse.code {
                            case 0..<200: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                Trace.trace(Trace.Level.INFO, message: "resultHandler error \(nse.code.description)", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
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
                                Trace.trace(Trace.Level.INFO, message: "resultHandler error \(nse.code.description)", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
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
                    Trace.trace(Trace.Level.DEBUG, message: "heard \(r.bestTranscription.formattedString)", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
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
                        strongSelf.context.dispatch(.activate)
                    }
                }
        })
    }
}

// MARK: SpeechProcessor implementation

extension AppleWakewordRecognizer: SpeechProcessor {
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    public func startStreaming() {
        self.prepareAudioEngine()
        self.audioEngine.prepare()
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    public func stopStreaming() {
        self.stopRecognition()
        self.dispatchWorker?.cancel()
        self.dispatchWorker = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    ///
    /// Processes audio in an async thread.
    /// - Parameter frame: Frame of audio samples.
    public func process(_ frame: Data) -> Void {
        if !self.recognitionTaskRunning && self.context.isSpeech && !self.context.isActive {
            do {
                try self.audioEngine.start()
                self.startRecognition()
            } catch let error {
                self.context.error = error
                self.context.dispatch(.error)
            }
        } else if context.isActive {
            self.stopRecognition()
            self.audioEngine.pause()
        }
    }
}
