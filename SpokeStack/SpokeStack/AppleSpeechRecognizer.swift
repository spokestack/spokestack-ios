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
    var configuration: RecognizerConfiguration = RecognizerConfiguration()
    weak var delegate: SpeechRecognizer?
    
    // MARK: private properties
    
    lazy private var audioSession: AVAudioSession = {
        return AVAudioSession.sharedInstance()
    }()
    
    lazy private var speechRecognizer: SFSpeechRecognizer = {
        return SFSpeechRecognizer(locale: NSLocale.current)!
    }()
    
    lazy private var audioEngine: AVAudioEngine = {
        return AVAudioEngine()
    }()
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var dispatchWorker: DispatchWorkItem?
    
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
        dispatchWorker?.cancel()
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
        context.isActive = false
    }
    
    // MARK: private functions
    
    private func prepareAudioEngine() {
        print("AppleSpeechRecognizer prepareAudioEngine")
        let buffer: Int = (self.configuration.sampleRate / 1000) * self.configuration.frameWidth
        let recordingFormat = self.audioEngine.inputNode.outputFormat(forBus: 0)
        self.audioEngine.inputNode.removeTap(onBus: 0) // a belt-and-suspenders approach to fixing https://github.com/wenkesj/react-native-voice/issues/46
        self.audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(buffer),
            format: recordingFormat)
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
                print("AppleSpeechRecognizer createRecognitionTask resultHandler \(String(describing: result))")
                guard let strongSelf = self else {
                    return
                }
                strongSelf.dispatchWorker?.cancel()
                if let e = error {
                    if let nse: NSError = error as NSError? {
                        if nse.domain == "kAFAssistantErrorDomain" {
                            switch nse.code {
                            case 203: // request timed out, retry
                                print("AppleSpeechRecognizer createRecognitionTask resultHandler error 203")
                                context.isActive = false
                                strongSelf.delegate?.didFinish()
                                break
                            case 209: // ¯\_(ツ)_/¯
                                print("AppleSpeechRecognizer createRecognitionTask resultHandler error 209")
                                break
                            case 216: // Apple internal error: https://stackoverflow.com/questions/53037789/sfspeechrecognizer-216-error-with-multiple-requests?noredirect=1&lq=1)
                                print("AppleSpeechRecognizer createRecognitionTask resultHandler error 216")
                                break
                            default:
                                strongSelf.delegate?.didError(e)
                            }
                        }
                    } else {
                        strongSelf.delegate?.didError(e)
                    }
                }
                if let r = result {
                    print("AppleSpeechRecognizer result " + r.bestTranscription.formattedString)
                    let confidence = r.transcriptions.first?.segments.sorted(
                        by: { (a, b) -> Bool in
                            a.confidence <= b.confidence }).first?.confidence ?? 0.0
                    context.transcript = r.bestTranscription.formattedString
                    context.confidence = confidence
                    strongSelf.dispatchWorker = DispatchWorkItem {[weak self] in
                        print("AppleSpeechRecognizer dispatchWorker")
                        context.isActive = false
                        self?.delegate?.didRecognize(context)
                        self?.delegate?.didFinish()
                    }
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(strongSelf.configuration.vadFallDelay), execute: strongSelf.dispatchWorker!)
                }
        })
    }
}
