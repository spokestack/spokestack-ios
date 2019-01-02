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
        
        let count: Int = Int(self.frameLength)
        let data = Data(bytes: self.spstk_float32Audio, count: count)

        return data
    }
    
    var spstk_float32Audio: Array<Float> {
        
        let leftChannel: UnsafeMutablePointer<Float> = self.floatChannelData![0]
        let count: Int = Int(self.frameLength)
        let audioArray: Array<Float> = Array(UnsafeBufferPointer(start: leftChannel, count: count))
        
        return audioArray
    }
}
