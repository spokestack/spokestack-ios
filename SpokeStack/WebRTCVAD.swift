//
//  WebRTCVAD.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/1/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import filter_audio

/// Indicate how likely it is that non-speech will activate the VAD.
public enum VADMode: Int {
    /// Most permissive of non-speech; most likely to detect speech.
    case HighlyPermissive = 1
    /// Allows more non-speech than higher levels.
    case Permissive = 2
    /// Allows less non-speech than higher levels.
    case Restrictive = 3
    /// Most restrictive of non-speech; most amount of missed speech.
    case HighlyRestrictive = 4
}

private var vad: UnsafeMutablePointer<OpaquePointer?> = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)

private var frameBufferStride: Int = 0
private var frameBufferStride32: Int32 = 0
private var sampleRate32: Int32 = 16000

private var frameBuffer: RingBuffer<Int16>!

/// Swift wrapper for WebRTC's voice activity detector.
public class WebRTCVAD: NSObject {
    
    /// Callback delegate for activation and error events.
    public var delegate: VADDelegate?
    
    deinit {
        WebRtcVad_Free(vad.pointee)
        vad.deallocate()
    }
    
    ///  Creates and configures a new WebRTC VAD component.
    /// - Parameter mode: Indicate to the VAD the level of permissiveness to non-speech activation.
    /// - Parameter delegate: Callback delegate for activation and error events.
    /// - Parameter frameWidth: Number of samples in an audio frame.
    /// - Parameter sampleRate: Rate of the samples in an audio frame.
    ///
    /// - Throws: VADError.invalidConfiguration if the frameWidth or sampleRate are not supported.
    public func create(mode: VADMode, delegate: VADDelegate, frameWidth: Int, sampleRate: Int) throws {
        
        /// validation of configurable parameters
        try self.validate(frameWidth: frameWidth, sampleRate: sampleRate)
        
        /// set public property
        self.delegate = delegate
        
        /// set private properties
        frameBufferStride = frameWidth*(sampleRate/1000) /// eg 20*(16000/1000) = 320
        sampleRate32 = Int32(sampleRate)
        frameBufferStride32 = Int32(frameBufferStride)
        frameBuffer = RingBuffer(frameBufferStride, repeating: 0)
        
        /// initialize WebRtcVad with provided configuration
        var errorCode:Int32 = 0
        errorCode = WebRtcVad_Create(vad)
        if errorCode != 0 { throw VADError.initialization("unable to create a WebRTCVAD struct, which returned error code \(errorCode)") }
        errorCode = WebRtcVad_Init(vad.pointee)
        if errorCode != 0 { throw VADError.initialization("unable to initialize WebRTCVAD, which returned error code \(errorCode)") }
        errorCode = WebRtcVad_set_mode(vad.pointee, Int32(mode.rawValue))
        if errorCode != 0 {
            WebRtcVad_Free(vad.pointee)
            throw VADError.initialization("unable to set WebRTCVAD mode, which returned error code \(errorCode)")
        }
    }
    
    private func validate(frameWidth: Int, sampleRate: Int) throws {
        switch frameWidth {
        case 10, 20, 30: break
        default: throw VADError.invalidConfiguration("Invalid frameWidth of \(frameWidth)")
        }
        
        switch sampleRate {
        case 8000, 16000, 32000, 48000: break
        default: throw VADError.invalidConfiguration("Invalid sampleRate of \(sampleRate)")
        }
    }
    
    /// Processes an audio frame, detecting speech.
    /// - Parameter frame: Audio frame of samples.
    /// - Parameter isSpeech: Whether speech was detected in the last frame.
    ///
    /// - Throws: RingBufferStateError.illegalState if the frame buffer enters an invalid state
    public func process(frame: Data, isSpeech: Bool) throws -> Void {
        do {
            var detected: Bool = false
            let samples: Array<Int16> = frame.elements()
            for s in samples {
                /// write the frame sample to the buffer
                try frameBuffer.write(s)
                if frameBuffer.isFull {
                    /// once the buffer is full, process its samples
                    detecting: while !frameBuffer.isEmpty {
                        var sampleWindow: Array<Int16> = []
                        for _ in 0..<frameBufferStride {
                            if !frameBuffer.isEmpty {
                                let s: Int16 = try frameBuffer.read()
                                sampleWindow.append(s)
                            }
                        }
                        let sampleWindowUBP = Array(UnsafeBufferPointer(start: sampleWindow, count: sampleWindow.count))
                        let result = WebRtcVad_Process(vad.pointee, sampleRate32, sampleWindowUBP, frameBufferStride32)
                        switch result {
                        // if activation state changes, stop the detecting loop but finish writing the samples to the buffer (in the outer for loop)
                        case 1:
                            // only activate at the highest VAD confidence level
                            detected = true
                            break detecting
                        default:
                            // WebRtcVad_Process error case
                            // self.delegate?.deactivate()
                            break
                        }
                    }
                }
            }
            if detected {
                if !isSpeech {
                    self.delegate?.activate(frame: frame)
                }
            } else {
                if isSpeech {
                    self.delegate?.deactivate()
                }
            }
        } catch let error {
            throw VADError.processing("error occurred while vad is processing \(error.localizedDescription)")
        }
    }
}
