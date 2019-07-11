//
//  WebRTCVAD.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 7/1/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import filter_audio

public enum VADMode: Int {
    case HighQuality
    case Quality
    case Agressive
    case HighlyAgressive
}

public enum VADDecision: Int {
    case None
    case Uncertain
    case Possible
    case Low
    case Medium
    case High
    case Highest
}

private var vad: UnsafeMutablePointer<OpaquePointer?> = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)

private var frameBufferStride: Int = 0
private var frameBufferStride32: Int32 = 0

private var frameBuffer: RingBuffer<Int16>!

public class WebRTCVAD: NSObject {
    public var delegate: VADDelegate?
    
    init(frameWidth: Int) {
        frameBufferStride = frameWidth*16
        frameBufferStride32 = Int32(frameBufferStride)
        frameBuffer = RingBuffer(frameBufferStride*4, repeating: 0) /// frame width * sample rate/1000 * 2 allows for variablely-sized frames
        super.init()
    }
    
    deinit {
        WebRtcVad_Free(vad.pointee)
        vad.deallocate()
    }
    
    public func create(mode: VADMode, delegate: VADDelegate) throws {
        self.delegate = delegate
        var errorCode:Int32 = 0
        errorCode = WebRtcVad_Create(vad)
        assert(errorCode == 0, "unable to create a WebRTCVAD struct, which returned error code \(errorCode)")
        errorCode = WebRtcVad_Init(vad.pointee)
        assert(errorCode == 0, "unable to initialize WebRTCVAD, which returned error code \(errorCode)")
        errorCode = WebRtcVad_set_mode(vad.pointee, Int32(mode.rawValue))
        if errorCode != 0 {
            WebRtcVad_Free(vad.pointee)
            assert(errorCode == 0, "unable to set WebRTCVAD mode, which returned error code \(errorCode)")
        }
    }
    
    public func process(sampleRate: Int32, frame: Data) -> Void {
        do {
            /// write the frame to the buffer
            let frameSamples: Array<Int16> = frame.elements()
            for (i, s) in frameSamples.enumerated() {
                try frameBuffer.write(s)
            }
            
            /// if the buffer has enough elements, process a sample
            if (abs(frameBuffer.available) >= frameBufferStride) {
                var sampleWindow: Array<Int16> = []
                for i in 0..<frameBufferStride {
                    if !frameBuffer.isEmpty {
                        let s: Int16 = try frameBuffer.read()
                        sampleWindow.append(s)
                    }
                }
                let sampleWindowP = Array(UnsafeBufferPointer(start: sampleWindow, count: sampleWindow.count))
                let result = WebRtcVad_Process(vad.pointee, sampleRate, sampleWindowP, frameBufferStride32)
                print("WebRtcVad_Process result \(result)")
                switch result {
                case 1:
                    self.delegate?.activate(frame: frame)
                    break
                case 0:
                    self.delegate?.deactivate()
                    break
                default:
                    /// WebRtcVad_Process error case
                    // self.delegate?.deactivate()
                    break
                }
            }
        } catch RingBufferStateError.illegalState(let message) {
            fatalError("WebRTCVAD process illegal state error \(message)")
        } catch let error {
            fatalError("WebRTCVAD process unknown error occurred while processing \(error.localizedDescription)")
        }
    }
}
