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
    case failedToSTart(message: String)
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
        
        let node: AVAudioInputNode = self.engine.inputNode
        let outputFormat: AVAudioFormat = node.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(self.bufferSize)
        
        
        ///
        
//        let downMixer = AVAudioMixerNode()
//        self.engine.attach(downMixer)
        
        ///

        node.installTap(onBus: 0,
                         bufferSize: bufferSize,
                         format: outputFormat,
                         block: {[weak self] buffer, time in

                            guard let strongSelf = self else {
                                return
                            }
                            
                            ////
                            
//                            var theLength = Int(buffer.frameLength)
//                            print("theLength = \(theLength)")
//                            
//                            var samplesAsDoubles:[Double] = []
//                            for i in 0 ..< Int(buffer.frameLength)
//                            {
//                                var theSample = Double((buffer.floatChannelData?.pointee[i])!)
//                                samplesAsDoubles.append( theSample )
//                            }
//                            
//                            print("samplesAsDoubles = \(samplesAsDoubles)")
                            
                            ////

                            print("buffer comingff back \(Int(buffer.frameLength)) and time \(time) and capacity \(buffer.frameCapacity)")
                            DispatchQueue.main.async {
                                strongSelf.delegate?.didReceive(buffer)
                            }
        })
        
        do {
            
            ///
//            let format = node.inputFormat(forBus: 0)
//            let format16KHzMono = AVAudioFormat.init(commonFormat: .pcmFormatInt16, sampleRate: 8000, channels: 1, interleaved: true)
//
//            self.engine.connect(node, to: downMixer, format: format)
//            self.engine.connect(downMixer, to: self.engine.mainMixerNode, format: format16KHzMono)
            
            ///
            
            self.engine.prepare()
            try self.engine.start()
            
            self.delegate?.didStart(self)

        } catch let error {
            
            throw AudioEngineControllerError.failedToSTart(message: error.localizedDescription)
        }
    }
    
    func stopRecording() -> Void {
        
        self.engine.inputNode.removeTap(onBus: 0)
        self.engine.stop()
        self.delegate?.didStop(self)
    }
}
