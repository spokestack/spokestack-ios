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
    
    // MARK: public properties
    
    /// Configuration for the recognizer.
    public var configuration: SpeechConfiguration?

    /// Delegate which receives speech pipeline control events.
    public weak var delegate: SpeechEventListener?
    /// Global state for the speech pipeline.
    public var context: SpeechContext?
    
    // MARK: private properties
    
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
    
    public init(_ configuration: SpeechConfiguration) {
        self.configuration = configuration
        super.init()
        self.configure()
    }
    
    private func configure() {
        guard let config = self.configuration else { return }
        // wakeword
        phrases = config.wakewords.components(separatedBy: ",")
        // Tracing
        self.traceLevel = config.tracing
    }
    
    // MARK: private functions
    
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
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakewordRequestTimeout), execute: self.dispatchWorker!)
        } catch let error {
            self.configuration?.delegateDispatchQueue.async {
                self.delegate?.failure(speechError: error)
            }
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
                                strongSelf.configuration?.delegateDispatchQueue.async {
                                    delegate.failure(speechError: e)
                                }
                            }
                        }
                    } else {
                        delegate.failure(speechError: e)
                    }
                }
                if let r = result {
                    Trace.trace(Trace.Level.DEBUG, message: "hears \(r.bestTranscription.formattedString)", config: strongSelf.configuration, context: strongSelf.context, caller: strongSelf)
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
                        strongSelf.context?.isActive = true
                        strongSelf.configuration?.delegateDispatchQueue.async {
                            delegate.didActivate()
                        }
                    }
                }
        })
    }
}

// MARK: SpeechProcessor implementation

extension AppleWakewordRecognizer: SpeechProcessor {
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    /// - Parameter context: The current speech context.
    public func startStreaming(context: SpeechContext) {
        self.context = context
        self.prepareAudioEngine()
        self.audioEngine.prepare()
        self.context?.isStarted = true
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    /// - Parameter context: The current speech context.
    public func stopStreaming(context: SpeechContext) {
        self.context = context
        self.stopRecognition()
        self.dispatchWorker?.cancel()
        self.dispatchWorker = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.context?.isStarted = false
    }
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    ///
    /// Processes audio in an async thread.
    /// - Parameter frame: Frame of audio samples.
    public func process(_ frame: Data) -> Void {
        guard let context = self.context else { return }
        if context.isSpeech {
            if !context.isActive {
                do {
                    try self.audioEngine.start()
                    self.startRecognition()
                } catch let error {
                    self.configuration?.delegateDispatchQueue.async {
                        self.delegate?.failure(speechError: error)
                    }
                }
            }
        } else if context.isActive {
            self.stopRecognition()
            self.audioEngine.pause()
        }
    }
}
