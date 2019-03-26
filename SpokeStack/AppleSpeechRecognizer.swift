//
//  AppleSpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 1/10/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

class AppleSpeechRecognizer: NSObject, SpeechRecognizerService {
    
    // MARK: public properties
    
    static let sharedInstance: AppleSpeechRecognizer = AppleSpeechRecognizer()
    var configuration: RecognizerConfiguration?
    weak var delegate: SpeechRecognizer?
    
    // MARK: private properties
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var vadFallWorker: DispatchWorkItem?
    private var wakeActiveMaxWorker: DispatchWorkItem?
    
    // MARK: NSObject methods
    
    deinit {
        print("AppleSpeechRecognizer deinit")
        speechRecognizer.delegate = nil
    }
    
    override init() {
        print("AppleSpeechRecognizer init")
        super.init()
    }
    
    // MARK: SpeechRecognizerService implementation
    
    func startStreaming(context: SpeechContext) {
        print("AppleSpeechRecognizer startStreaming")
        do {
            context.isActive = true
            self.prepareAudioEngine()
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask(context: context)
            self.audioEngine.prepare()
            try self.audioEngine.start()
            self.wakeActiveMaxWorker = DispatchWorkItem {[weak self] in
                print("AppleSpeechRecognizer wakeActiveMaxWorker")
                context.isActive = false
                self?.delegate?.timeout()
                self?.delegate?.deactivate()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakeActiveMax), execute: self.wakeActiveMaxWorker!)
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    func stopStreaming(context: SpeechContext) {
        print("AppleSpeechRecognizer stopStreaming")
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
        print("AppleSpeechRecognizer prepareAudioEngine")
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
                print("AppleSpeechRecognizer createRecognitionTask resultHandler")
                guard let strongSelf = self else {
                    print("AppleSpeechRecognizer recognitionTask resultHandler strongSelf is nil")
                    return
                }
                guard let delegate = strongSelf.delegate else {
                    print("AppleSpeechRecognizer recognitionTask resultHandler delegate is nil")
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
                                print("AppleSpeechRecognizer createRecognitionTask resultHandler error 203")
                                context.isActive = false
                                delegate.deactivate()
                                break
                            case 209: // ¯\_(ツ)_/¯
                                print("AppleSpeechRecognizer createRecognitionTask resultHandler error 209")
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                print("AppleSpeechRecognizer createRecognitionTask resultHandler error 216")
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
                    print("AppleSpeechRecognizer result " + r.bestTranscription.formattedString)
                    strongSelf.wakeActiveMaxWorker?.cancel()
                    let confidence = r.transcriptions.first?.segments.sorted(
                        by: { (a, b) -> Bool in
                            a.confidence <= b.confidence }).first?.confidence ?? 0.0
                    context.transcript = r.bestTranscription.formattedString
                    context.confidence = confidence
                    strongSelf.vadFallWorker = DispatchWorkItem {[weak self] in
                        print("AppleSpeechRecognizer vadFallWorker")
                        context.isActive = false
                        self?.delegate?.didRecognize(context)
                        self?.delegate?.deactivate()
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration!.vadFallDelay), execute: strongSelf.vadFallWorker!)
                }
        })
    }
}
