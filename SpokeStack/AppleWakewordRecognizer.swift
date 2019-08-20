//
//  AppleWakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/4/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

public class AppleWakewordRecognizer: NSObject, WakewordRecognizerService {
    
    // MARK: public properties
    
    static let sharedInstance: AppleWakewordRecognizer = AppleWakewordRecognizer()
    public var configuration: WakewordConfiguration?
    public weak var delegate: WakewordRecognizer?
    
    // MARK: wakeword properties
    
    private var phrases: Array<String> = []
    
    // MARK: recognition properties
    
    private let speechRecognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: NSLocale.current)!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine: AVAudioEngine = AVAudioEngine()
    private var dispatchWorker: DispatchWorkItem?
    private var vad: WebRTCVAD = WebRTCVAD()
    private var context: SpeechContext?
    
    // MARK: NSObject methods
    
    deinit {
        print("AppleWakewordRecognizer deinit")
        self.speechRecognizer.delegate = nil
    }
    
    public override init() {
        super.init()
        print("AppleWakewordRecognizer init")
    }
    
    // MARK: SpeechRecognizerService implementation
    
    func startStreaming(context: SpeechContext) {
        print("AppleWakewordRecognizer startStreaming")
        AudioController.shared.delegate = self
        phrases = configuration!.wakePhrases.components(separatedBy: ",")
        self.context = context
        self.prepareAudioEngine()
        self.audioEngine.prepare()
    }
    
    func stopStreaming(context: SpeechContext) {
        print("AppleWakewordRecognizer stopStreaming")
        AudioController.shared.delegate = nil
        self.context = context
        self.stopRecognition()
        self.dispatchWorker?.cancel()
        self.dispatchWorker = nil
        self.audioEngine.stop()
        self.audioEngine.inputNode.removeTap(onBus: 0)
    }
    
    // MARK: private functions
    
    private func prepareAudioEngine() {
        print("AppleWakewordRecognizer prepareAudioEngine")
        
        do {
            try self.vad.create(mode: .HighQuality,
                                delegate: self,
                                frameWidth: self.configuration!.frameWidth,
                                samplerate: self.configuration!.sampleRate)
        } catch {
            assertionFailure("CoreMLWakewordRecognizer failed to create a valid VAD")
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
        print("AppleWakewordRecognizer startRecognition")
        do {
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.shouldReportPartialResults = true
            try self.createRecognitionTask()
            
            // Automatically restart wakeword task if it goes over Apple's 1 minute listening limit
            self.dispatchWorker = DispatchWorkItem {[weak self] in
                print("AppleWakewordRecognizer dispatchWorker")
                self?.stopRecognition()
                self?.startRecognition()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(self.configuration!.wakewordRequestTimeout), execute: self.dispatchWorker!)
        } catch let error {
            self.delegate?.didError(error)
        }
    }
    
    private func stopRecognition() {
        print("AppleWakewordRecognizer stopRecognition")
        self.recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognitionRequest?.endAudio()
        self.recognitionRequest = nil
    }
    
    private func createRecognitionTask() throws -> Void {
        print("AppleWakewordRecognizer createRecognitionTask")
        self.recognitionTask = self.speechRecognizer.recognitionTask(
            with: recognitionRequest!,
            resultHandler: {[weak self] result, error in
                print("AppleWakewordRecognizer recognitionTask resultHandler")
                guard let strongSelf = self else {
                    print("AppleWakewordRecognizer recognitionTask resultHandler strongSelf is nil")
                    return
                }
                guard let delegate = strongSelf.delegate else {
                    print("AppleWakewordRecognizer recognitionTask resultHandler delegate is nil")
                    return
                }
                if let e = error {
                    if let nse: NSError = error as NSError? {
                        if nse.domain == "kAFAssistantErrorDomain" {
                            switch nse.code {
                            case 0..<200: // Apple retry error: https://developer.nuance.com/public/Help/DragonMobileSDKReference_iOS/Error-codes.html
                                print("AppleWakewordRecognizer createRecognitionTask resultHandler error " + nse.code.description)
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
                                print("AppleWakewordRecognizer createRecognitionTask resultHandler error " + nse.code.description)
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
                    print("AppleWakewordRecognizer hears " + r.bestTranscription.formattedString)
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
                        print("AppleWakewordRecognizer wakeword detected")
                        delegate.activate()
                    }
                }
        })
    }
}

extension AppleWakewordRecognizer: AudioControllerDelegate {
    func processFrame(_ frame: Data) -> Void {
        audioProcessingQueue.async {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.vad.process(frame: frame, isSpeech: true)
        }
    }
}

extension AppleWakewordRecognizer: VADDelegate {
    public func activate(frame: Data) {
        print("AppleWakewordRecognizer activate")
        if let c = self.context {
            if (c.isActive) {
                // asr is active, so don't interrupt
            } else {
                do {
                    try self.audioEngine.start()
                    self.startRecognition()
                } catch let error {
                    self.delegate?.didError(error)
                }
            }
        }
    }
    
    public func deactivate() {
        print("AppleWakewordRecognizer deactivate")
        if let c = self.context {
            if (c.isActive) {
                // asr is active, so don't interrupt
            } else {
                self.stopRecognition()
                self.audioEngine.pause()
            }
        }
    }
}
