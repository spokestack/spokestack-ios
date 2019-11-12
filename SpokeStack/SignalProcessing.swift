//
//  SignalProcessingAlgorithms.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 8/9/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

// Root Mean Squared and Hann algorithms

/// Static namepsace for signal processing functions.
public struct SignalProcessing {
    /// Find the root mean squared of a frame buffer of samples.
    /// - Parameter frame: Frame of samples.
    /// - Parameter dataElements: Preallocated array of data elements in the frame.
    /// - Returns: The RMS of the frame.
    public static func rms(_ frame: Data, _ dataElements: Array<Int16>) -> Float {
        var sum: Float = 0
        
        /// Process all samples in the frame
        /// calculating the sum of the squares of the samples
        for d in dataElements {
            let sample: Float = Float(d) / Float(Int16.max)
            sum += sample * sample
        }
        
        /// calculate RMS
        return Float(sqrt(sum / Float(dataElements.count)))
    }
    
    /// Convenience enum for Fast Fourier Transform window types.
    public enum FFTWindowType: String {
        case hann
    }
    
    /// Convenience function to find the window of a FFT.
    /// - Parameter windowType: The FFT window type.
    /// - Parameter windowLength: The size of the window.
    public static func fftWindowDispatch(windowType: FFTWindowType, windowLength: Int) -> Array<Float> {
        switch windowType {
        case .hann: return hannWindow(windowLength)
        }
    }
    
    /// Implementation of the Hann smoothing function algorithm.
    /// - Parameter length: The size of the window to find.
    /// - Note: https://en.wikipedia.org/wiki/Hann_function
    /// - Returns: The Hann window.
    public static func hannWindow(_ length: Int) -> Array<Float> {
        var window: Array<Float> = Array(repeating: 0, count: length)
        for (index, _) in window.enumerated() {
            window[index] = Float(pow(sin((Float.pi * Float(index)) / Float((length - 1))), 2))
        }
        return window
    }
}
