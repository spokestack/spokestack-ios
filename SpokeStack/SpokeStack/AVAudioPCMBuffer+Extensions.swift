//
//  AVAudioPCMBuffer+Extensions.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/13/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAudioPCMBuffer {

    // MARK: Internal (properties)
    
    var spstk_data: Data {
        
        let audioBuffer: (AudioBuffer) = self.audioBufferList.pointee.mBuffers
        let data: Data = Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))

        return data
    }
}
