//
//  FFT.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 12/6/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Accelerate

/// Performs a Fast Fourier Transform on a given buffer of samples.
final class FFT {
    
    // MARK: Private (properties)
    
    private(set) var size: Int
    private var halfSize: Int
    private var log2Size: Int
    private var fftSetup: FFTSetup
    private var real_part: Array<Float>
    private var imaginary_part: Array<Float>
    private var complexBuffer: DSPSplitComplex

    // MARK: Initializers
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    /// Initializes a new FFT instance.
    /// - Parameter size: size of sample buffer that will be given in `forward`.
    required init(_ size: Int) {
        let sizeFloat: Float = Float(size)

        /// Check if the size is a power of two
        let lg2: Float = logbf(sizeFloat)
        assert(remainderf(sizeFloat, powf(2.0, lg2)) == 0, "size must be a power of 2")
        self.size = size
        self.halfSize = size / 2
        
        /// Create FFT setup
        self.log2Size = Int(log2f(sizeFloat))
        self.fftSetup = vDSP_create_fftsetup(UInt(log2Size), FFTRadix(FFT_RADIX2))!
        
        /// Init the complexBuffer
        self.real_part = [Float](repeating: 0.0, count: self.halfSize)
        self.imaginary_part = [Float](repeating: 0.0, count: self.halfSize)
        self.complexBuffer = DSPSplitComplex(realp: &real_part, imagp: &imaginary_part)
    }
    
    // MARK: Public (methods)
    
    /// Perform a Fast Fourier Transform on the provided buffer of samples.
    /// - Parameter buffer: a buffer of samples.
    func forward(_ buffer: inout Array<Float>) -> Void {
        /// Pack the sample values into the FFT complex buffer
        for i in 0..<self.halfSize {
            self.complexBuffer.realp[i] = buffer[2 * i + 0]
            self.complexBuffer.imagp[i] = buffer[2 * i + 1]
        }
        
        /// Perform a forward FFT
        vDSP_fft_zrip(self.fftSetup, &(self.complexBuffer), 1, UInt(self.log2Size), Int32(FFT_FORWARD))
        
        /// Store and square (for better visualization & conversion to db) the magnitudes
        vDSP_zvmags(&(self.complexBuffer), 1, &buffer, 1, UInt(self.halfSize))
        buffer[0] = self.complexBuffer.realp[0] * self.complexBuffer.realp[0]
        buffer[self.halfSize] = self.complexBuffer.imagp[0] * self.complexBuffer.imagp[0]
        for i in 0..<self.halfSize + 1 {
            buffer[i] = sqrt(buffer[i]) / 2
        }
    }
}
