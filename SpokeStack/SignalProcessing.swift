//
//  SignalProcessingAlgorithms.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 8/9/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

// Root Mean Squared and Hann algorithms

public struct SignalProcessing {
    public static func rms(_ frame: Data, _ dataElements: Array<Int16>) -> Float {
        var sum: Float = 0
        
        /// Process all samples in the frame
        /// calculating the sum of the squares of the samples
        for d in dataElements {
            let sample: Float = Float(d) / Float(Int16.max)
            sum += sample * sample
        }
        
        /// calculate rms
        return Float(sqrt(sum / Float(dataElements.count)))
    }
    
    public enum FFTWindowType: String {
        case hann
    }
    
    public static func fftWindowDispatch(windowType: FFTWindowType, windowLength: Int) -> Array<Float> {
        switch windowType {
        case .hann: return hannWindow(windowLength)
        }
    }
    
    public static func hannWindow(_ length: Int) -> Array<Float> {
        /// https://en.wikipedia.org/wiki/Hann_function
        var window: Array<Float> = Array(repeating: 0, count: length)
        for (index, _) in window.enumerated() {
            window[index] = Float(pow(sin((Float.pi * Float(index)) / Float((length - 1))), 2))
        }
        return window
    }
}
