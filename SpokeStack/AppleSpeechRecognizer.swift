//
//  AppleSpeechRecognizer.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 1/10/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

@objc public class AppleSpeechRecognizer: NSObject, SpeechProcessor {
    
    // MARK: public properties
    
    @objc public static let sharedInstance: AppleSpeechRecognizer = AppleSpeechRecognizer()
    public var configuration: SpeechConfiguration?
    public weak var delegate: SpeechEventListener?
    public var context: SpeechContext = SpeechContext()
    
    // MARK: private properties
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var vadFallWorker: DispatchWorkItem?
    private var wakeActiveMaxWorker: DispatchWorkItem?
    
    // MARK: NSObject methods
    
    deinit {
        speechRecognizer.delegate = nil
    }
    
    override init() {
        super.init()
    }
    
    // MARK: SpeechRecognizerService implementation
    
    public func startStreaming(context: SpeechContext) {
        do {
            context.isActive = true
            self.prepareAudioEngine()
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask(context: context)
            self.audioEngine.prepare()
            try self.audioEngine.start()
            self.wakeActiveMaxWorker = DispatchWorkItem {[weak self] in
                context.isActive = false
                self?.delegate?.didTimeout()
                self?.delegate?.deactivate()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakeActiveMax), execute: self.wakeActiveMaxWorker!)
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    public func stopStreaming(context: SpeechContext) {
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
        self.vadFallWorker?.cancel()
        self.wakeActiveMaxWorker?.cancel()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        context.isActive = false
    }
    
    // MARK: private functions
    
    private func prepareAudioEngine() {
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
    
    private func createRecognitionTask(context: SpeechContext) throws -> Void {
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: {[weak self] result, error in
                guard let strongSelf = self else {
                    assertionFailure("AppleSpeechRecognizer recognitionTask resultHandler strongSelf is nil")
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
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "resultHandler error 203", delegate: strongSelf.delegate, caller: strongSelf)
                                context.isActive = false
                                delegate.deactivate()
                                break
                            case 209: // ¯\_(ツ)_/¯
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "resultHandler error 209", delegate: strongSelf.delegate, caller: strongSelf)
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                Trace.trace(Trace.Level.INFO, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "resultHandler error 216", delegate: strongSelf.delegate, caller: strongSelf)

                                break
                            case 300..<603: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
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
                    Trace.trace(Trace.Level.DEBUG, configLevel: strongSelf.configuration?.tracing ?? Trace.Level.NONE, message: "recognized \(r.bestTranscription.formattedString)", delegate: strongSelf.delegate, caller: strongSelf)
                    strongSelf.wakeActiveMaxWorker?.cancel()
                    let confidence = r.transcriptions.first?.segments.sorted(
                        by: { (a, b) -> Bool in
                            a.confidence <= b.confidence }).first?.confidence ?? 0.0
                    context.transcript = r.bestTranscription.formattedString
                    context.confidence = confidence
                    strongSelf.vadFallWorker = DispatchWorkItem {[weak self] in
                        context.isActive = false
                        self?.delegate?.didRecognize(context)
                        self?.delegate?.deactivate()
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration!.vadFallDelay), execute: strongSelf.vadFallWorker!)
                }
        })
    }
}
