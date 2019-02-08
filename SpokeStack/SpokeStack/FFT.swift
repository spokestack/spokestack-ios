//
//  FFT.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/6/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Accelerate

final class FFT {
    
    // MARK: Public (properties)
    
    private(set) var size: Int
    
    // MARK: Private (properties)
    
    private var halfSize: Int
    
    private var log2Size: Int
    
//    private var window: Array<Float> = []
    
    private var fftSetup: FFTSetup
    
    private var complexBuffer: DSPSplitComplex!

//    private var magnitudes: Array<Float> = []
    
    // MARK: Initializers
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
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
        
        var real: Array<Float> = [Float](repeating: 0.0, count: self.halfSize)
        var imaginary: Array<Float> = [Float](repeating: 0.0, count: self.halfSize)
        
        self.complexBuffer = DSPSplitComplex(realp: &real, imagp: &imaginary)
    }
    
    // MARK: Public (methods)

    func forward(_ buffers: Array<Float>) -> Void {
        
        var analysisBuffer = buffers
        
//        if self.window.isEmpty {
//
//            self.window = [Float](repeating: 0.0, count: size)
//            vDSP_hann_window(&self.window, UInt(size), Int32(vDSP_HANN_NORM))
//        }

        /// Apply the window

//        vDSP_vmul(buffers, 1, self.window, 1, &analysisBuffer, 1, UInt(buffers.count))
        
        var reals: Array<Float> = []
        var imags: Array<Float> = []

        for (idx, element) in analysisBuffer.enumerated() {
            
            reals.append(element)
            imags.append(0)
        }
        
        self.complexBuffer = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: reals),
                                             imagp: UnsafeMutablePointer(mutating: imags))
        
        /// Perform a forward FFT
        
        vDSP_fft_zrip(self.fftSetup, &(self.complexBuffer!), 1, UInt(self.log2Size), Int32(FFT_FORWARD))
        
        /// Store and square (for better visualization & conversion to db) the magnitudes
        
//        self.magnitudes = [Float](repeating: 0.0, count: self.halfSize)
        vDSP_zvmags(&(self.complexBuffer!), 1, &analysisBuffer, 1, UInt(self.halfSize))
//        analysisBuffer.append(contentsOf: self.magnitudes)
    }
}
