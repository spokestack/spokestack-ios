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
    
    var spstk_16BitAudioData: Data {
        
        let channels = UnsafeBufferPointer(start: int16ChannelData, count: 1)
        let ch0Data = Data(bytes: UnsafeMutablePointer<Int16>(channels[0]),
                           count: Int(frameCapacity * format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data
    }
    
    var spstk_data: Data {
        
        let count: Int = Int(self.frameLength)
        let data = Data(bytes: self.spstk_int16Audio, count: count)

        return data
    }
    
    var spstk_float32Audio: Array<Float> {
        
        let leftChannel: UnsafeMutablePointer<Float> = self.floatChannelData![0]
        let count: Int = Int(self.frameLength)
        let audioArray: Array<Float> = Array(UnsafeBufferPointer(start: leftChannel, count: count))
        
        return audioArray
    }
    
    var spstk_int16Audio: Array<Int16> {
        
        let leftChannel: UnsafeMutablePointer<Int16> = self.int16ChannelData![0]
        let count: Int = Int(self.frameLength)
        let audioArray: Array<Int16> = Array(UnsafeBufferPointer(start: leftChannel, count: count))
        
        return audioArray
    }
}
