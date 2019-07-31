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
private var sampleRate: Int32 = 16000

private var frameBuffer: RingBuffer<Int16>!

public class WebRTCVAD: NSObject {
    public var delegate: VADDelegate?
    
    deinit {
        WebRtcVad_Free(vad.pointee)
        vad.deallocate()
    }
    
    public func create(mode: VADMode, delegate: VADDelegate, frameWidth: Int, samplerate: Int) throws {
        self.delegate = delegate
        sampleRate = Int32(samplerate) // 16000
        frameBufferStride = frameWidth*(samplerate/1000) // 20*16 = 320
        frameBufferStride32 = Int32(frameBufferStride) // 320
        frameBuffer = RingBuffer(frameBufferStride*4, repeating: 0) /// frame width * sample rate/1000 * magic number 4 allowing for variablely-sized frames = 1280
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
    
    public func process(frame: Data, isSpeech: Bool) -> Void {
        do {
            /// write the frame to the buffer
            let frameSamples: Array<Int16> = frame.elements()
            for s in frameSamples {
                if !frameBuffer.isFull {
                    try frameBuffer.write(s)
                } else {
                    /// once the buffer is full, process its samples
                    while !frameBuffer.isEmpty {
                        var sampleWindow: Array<Int16> = []
                        for _ in 0..<frameBufferStride {
                            if !frameBuffer.isEmpty {
                                let s: Int16 = try frameBuffer.read()
                                sampleWindow.append(s)
                            }
                        }
                        let sampleWindowUBP = Array(UnsafeBufferPointer(start: sampleWindow, count: sampleWindow.count))
                        let result = WebRtcVad_Process(vad.pointee, sampleRate, sampleWindowUBP, frameBufferStride32)
                        print("WebRtcVad_Process result \(result)")
                        switch result {
                        case 1:
                            if !isSpeech {
                                self.delegate?.activate(frame: frame)
                            }
                            break
                        case 0:
                            if isSpeech {
                                self.delegate?.deactivate()
                            }
                            break
                        default:
                            /// WebRtcVad_Process error case
                            // self.delegate?.deactivate()
                            break
                        }
                    }
                }
            }
        } catch RingBufferStateError.illegalState(let message) {
            fatalError("WebRTCVAD process illegal state error \(message)")
        } catch let error {
            fatalError("WebRTCVAD process unknown error occurred while processing \(error.localizedDescription)")
        }
    }
}
