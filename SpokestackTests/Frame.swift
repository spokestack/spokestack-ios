//
//  Frame.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/18/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

public struct Frame {
    public static func voice(frameWidth: Int, sampleRate: Int) -> Data {
        let freq: Float = 2000.0
        let rate = Float(sampleRate)
        let capacity = frameWidth*(sampleRate/1000)
        var d = Array<Float>()
        for i in 0..<capacity {
            d.append(sin((Float(i) / (rate / freq)) * 2.0 * Float.pi))
        }
        let f = d.withUnsafeBufferPointer {Data(buffer: $0)}
        return f
    }
    
    public static func silence(frameWidth: Int, sampleRate: Int) -> Data {
        let d = [Int](repeating: 0, count: (sampleRate/1000)*frameWidth)
        let f = d.withUnsafeBufferPointer {Data(buffer: $0)}
        return f
    }
}
