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
    @objc public var configuration: SpeechConfiguration

    /// Global state for the speech pipeline.
    @objc public var context: SpeechContext
    
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
    
    /// Initializes a AppleWakewordRecognizer instance.
    ///
    /// A recognizer is initialized by, and receives `startStreaming` and `stopStreaming` events from, an instance of `SpeechPipeline`.
    ///
    /// The AppleWakewordRecognizer receives audio data frames to `process` from a tap into the system `AudioEngine`.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
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
    
    private func prepare() {
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
        self.audioEngine.prepare()
        self.dispatchWorker = DispatchWorkItem {[weak self] in
            self?.stopRecognition()
            self?.startRecognition()
        }
    }
    
    private func startRecognition() {
        do {
            try self.audioEngine.start()
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask()
            self.recognitionTaskRunning = true
            
            // Automatically restart wakeword task if it goes over Apple's 1 minute listening limit
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(self.configuration.wakewordRequestTimeout), execute: { if let timeoutWorker = self.dispatchWorker { timeoutWorker.perform() }})
        } catch let error {
            self.context.dispatch { $0.failure(error: error) }
        }
    }
    
    private func stopRecognition() {
        self.recognitionTaskRunning = false
        self.recognitionTask?.finish()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.audioEngine.pause()
    }
    
    private func createRecognitionTask() throws -> Void {
        guard let rr = self.recognitionRequest else {
            throw SpeechPipelineError.failure("Apple Wakeword's recognition request does not exist.")
        }
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: rr,
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
                                strongSelf.context.dispatch { $0.failure(error: e) }

                            }
                        }
                    } else {
                        strongSelf.context.dispatch { $0.failure(error: e) }
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
                        strongSelf.context.dispatch { $0.didActivate?() }
                    }
                }
        })
    }
}

// MARK: SpeechProcessor implementation

extension AppleWakewordRecognizer: SpeechProcessor {
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    @objc public func startStreaming() {
        self.prepare()
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    @objc public func stopStreaming() {
        self.stopRecognition()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.dispatchWorker?.cancel()
        self.dispatchWorker = nil
    }
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components. Processes audio in an async thread.
    /// - Note: Processes audio in an async thread.
    /// - Remark: The Apple Wakeword Recognizer hooks up directly to its own audio tap for processing audio frames. When the `AudioController` calls this `process`, it checks to see if the pipeline has detected speech, and if so kicks off its own VAD and wakeword recognizer independently of any other components in the speech pipeline.
    /// - Parameter frame: Frame of audio samples.
    @objc public func process(_ frame: Data) -> Void {
        if !self.recognitionTaskRunning && self.context.isSpeech && !self.context.isActive {
            self.startRecognition()
        } else if context.isActive {
            self.stopRecognition()
        }
    }
}
