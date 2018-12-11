//
//  AudioEngineController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/10/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation

final class AudioEngineController {
    
    // MARK: Private (properties)
    
    private let bufferSize: Int

    private var engine: AVAudioEngine = AVAudioEngine()
    
    private var audioBuffer:AVAudioPCMBuffer = AVAudioPCMBuffer()
    
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
            
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: .defaultToSpeaker)
            
            let ioBufferDuration = Double(bufferSize) / 44100.0
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(ioBufferDuration)
            
        } catch {
            
            assertionFailure("AVAudioSession setup error: \(error)")
        }
    }
    
    // MARK: Internal (methods)
    
    func startRecording() -> Void {

        let mixer = self.engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        
        mixer.installTap(onBus: 0,
                         bufferSize: AVAudioFrameCount(self.bufferSize),
                         format: format,
                         block: {buffer, time in
            
                            print("buffer coming back \(buffer.frameLength) and time \(time)")
        })
        
        try! self.engine.start()
    }
}
