//
//  AudioEngineController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/10/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation

protocol AudioEngineControllerDelegate: AnyObject {
    
    func didStart(_ engineController: AudioEngineController) -> Void
    func didStop(_ engineController: AudioEngineController) -> Void
    func didReceive(_ buffer: AVAudioPCMBuffer) -> Void
}

public enum AudioEngineControllerError: Error {
    case failedToStart(message: String)
}

final class AudioEngineController {
    
    // MARK: Internal (properties)
    
    weak var delegate: AudioEngineControllerDelegate?
    
    // MARK: Private (properties)
    
    private let bufferSize: Int

    private var engine: AVAudioEngine = AVAudioEngine()
    
    private var audioBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer()
    
    // MARK: Initializers
    
    deinit {
        engine.stop()
        engine.reset()
    }
    
    init(_ buffer: Int) {
        
        self.engine.stop()
        self.engine.reset()
        self.engine = AVAudioEngine()
        self.bufferSize = buffer
        
        do {
            
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord,
                                                            mode: .spokenAudio,
                                                            options: .defaultToSpeaker)
            
            let ioBufferDuration = Double(self.bufferSize) / 48000.0
            
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(ioBufferDuration)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
        } catch {
            
            assertionFailure("AVAudioSession setup error: \(error)")
        }
    }
    
    // MARK: Internal (methods)
    
    func startRecording() throws -> Void {
        
        let inputNode: AVAudioInputNode = self.engine.inputNode
        let outputFormat: AVAudioFormat = inputNode.outputFormat(forBus: 0)
        
        let formatIn: AVAudioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                    sampleRate: 16000,
                                                    channels: 1,
                                                    interleaved: false)!
        
        let formatOut: AVAudioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                     sampleRate: 16000,
                                                     channels: 1,
                                                     interleaved: false)!
        
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(self.bufferSize)
        
        guard let bufferMapper = AVAudioConverter(from: formatIn, to: formatOut) else {
            throw AudioEngineControllerError.failedToStart(message: "Failed to create buffer mapper")
        }
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: outputFormat, block: {[weak self] buffer, time in
            
            guard let strongSelf = self,
                let converted16BitBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: formatOut, frameCapacity: buffer.frameCapacity) else {
                    
                    fatalError("Can't create PCM buffer")
            }
            
            /// This is needed because the 'frameLenght' default value is 0
            /// (since iOS 10) and cause the 'convert' call to faile with an
            /// error (Error Domain=NSOSStatusErrorDomain Code=-50 "(null)")
            /// More here: http://stackoverflow.com/questions/39714244/avaudioconverter-is-broken-in-ios-10

            converted16BitBuffer.frameLength = converted16BitBuffer.frameCapacity
            
            do {
                
                try bufferMapper.convert(to: converted16BitBuffer, from: buffer)
                
            } catch(let error as NSError) {
                
                print(error)
                return
            }
            
//            let it16Buffer = converted16BitBuffer.spstk_float16Audio
//            let it32Buffer = buffer.spstk_float32Audio
//            print(
//            """
//            16 \(it16Buffer)
//            32 \(it32Buffer)
//            """
//            )
            DispatchQueue.main.async {
                strongSelf.delegate?.didReceive(converted16BitBuffer)
            }
        })
        
        do {
            
            self.engine.prepare()
            try self.engine.start()
            
            self.delegate?.didStart(self)

        } catch let error {
            
            throw AudioEngineControllerError.failedToStart(message: error.localizedDescription)
        }
    }
    
    func stopRecording() -> Void {
        
        self.engine.inputNode.removeTap(onBus: 0)
        self.engine.stop()
        self.delegate?.didStop(self)
    }
}
