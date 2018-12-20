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

        ///

        let leftChannel = self.floatChannelData![0]
        let count: Int = Int(self.frameLength)
        let arr = Array(UnsafeBufferPointer(start: leftChannel, count: count))
        let data = Data(bytes: leftChannel, count: count)

        print("what the arr \(arr)")
        print("what is the data length \(data.count)")
        
        ///

//        let audioBuffer: (AudioBuffer) = self.audioBufferList.pointee.mBuffers
//        print("what is the audioBuffer data size \(audioBuffer.mDataByteSize) and data \(String(describing: audioBuffer.mData))")
//        let data: Data = Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))

        return data
    }
}
