//
//  WebRTCVAD.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/1/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import filter_audio

/// Indicate how likely it is that non-speech will activate the VAD.
@objc public enum VADMode: Int {
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
@objc public class WebRTCVAD: NSObject, SpeechProcessor {

    /// Configuration for the recognizer.
    @objc public var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    @objc public var context: SpeechContext

    // vad detection length management
    private var detectionLength: Int = 0
    private var minDetectionLength: Int = 0
    private var maxDetectionLength: Int = 0
    private var isSpeechDetected: Bool = false

    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    @objc public func startStreaming() {}

    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    @objc public func stopStreaming() {}

    /// Initializes a WebRTCVAD instance.
    ///
    /// A recognizer is initialzed by, and recieves `startStreaming` and `stopStreaming` events from, an instance of `SpeechPipeline`.
    ///
    /// The WebRTCVAD receives audio data frames to `process` from `AudioController`.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        self.context.isSpeech = false
        super.init()
        do {
            try self.configure()
        } catch let error {
            self.context.error = error
            self.context.dispatch(.error)
        }
    }
    
    deinit {
        vad.deinitialize(count: 1)
    }
    
    /// Creates and configures a new WebRTC VAD component.
    ///
    ///  - Throws: VADError.invalidConfiguration if the frameWidth or sampleRate are not supported.
    private func configure() throws {
        let c = self.configuration
        // validation of configurable parameters
        try self.validate(frameWidth: c.frameWidth, sampleRate: c.sampleRate)
                
        // set private properties
        frameBufferStride = c.frameWidth*(c.sampleRate/1000) // eg 20*(16000/1000) = 320
        sampleRate32 = Int32(c.sampleRate)
        frameBufferStride32 = Int32(frameBufferStride)
        frameBuffer = RingBuffer(frameBufferStride, repeating: 0)
        self.minDetectionLength = c.wakeActiveMin / c.frameWidth
        self.maxDetectionLength = c.wakeActiveMax / c.frameWidth
        
        // initialize WebRtcVad with provided configuration
        var errorCode:Int32 = 0
        errorCode = WebRtcVad_Create(vad)
        if errorCode != 0 { throw VADError.initialization("unable to create a WebRTCVAD struct, which returned error code \(errorCode)") }
        errorCode = WebRtcVad_Init(vad.pointee)
        if errorCode != 0 { throw VADError.initialization("unable to initialize WebRTCVAD, which returned error code \(errorCode)") }
        errorCode = WebRtcVad_set_mode(vad.pointee, Int32(c.vadMode.rawValue))
        if errorCode != 0 {
            vad.pointee = nil
            throw VADError.initialization("unable to set WebRTCVAD mode, which returned error code \(errorCode)")
        }
    }
    
    private func validate(frameWidth: Int, sampleRate: Int) throws {
        switch frameWidth {
        case 10, 20, 30: break
        default:
            vad.pointee = nil
            throw VADError.invalidConfiguration("Invalid frameWidth of \(frameWidth)")
        }
        
        switch sampleRate {
        case 8000, 16000, 32000, 48000: break
        default:
            vad.pointee = nil
            throw VADError.invalidConfiguration("Invalid sampleRate of \(sampleRate)")
        }
    }
    
    /// Processes an audio frame, detecting speech.
    /// - Parameter frame: Audio frame of samples.
    @objc public func process(_ frame: Data) -> Void {
        do {
            var detected: Bool = false
            let samples: Array<Int16> = frame.elements()
            for s in samples {
                // write the frame sample to the buffer
                try frameBuffer.write(s)
                if frameBuffer.isFull {
                    // once the buffer is full, process its samples
                    detecting: while !frameBuffer.isEmpty {
                        var sampleWindow: Array<Int16> = []
                        for _ in 0..<frameBufferStride {
                            if !frameBuffer.isEmpty {
                                let s: Int16 = try frameBuffer.read()
                                sampleWindow.append(s)
                            }
                        }
                        let result = sampleWindow.withUnsafeBufferPointer {
                            return WebRtcVad_Process(vad.pointee, sampleRate32, $0.baseAddress, frameBufferStride32)
                        }
                        switch result {
                        // if activation state changes, stop the detecting loop but finish writing the samples to the buffer (in the outer for loop)
                        case 1:
                            // only activate at the highest VAD confidence level
                            detected = true
                            break detecting
                        default:
                            // WebRtcVad_Process error case
                            break
                        }
                    }
                }
            }
            // if speech activity is already detected, continue until the minimum detection length is reached
            if self.context.isSpeech && self.detectionLength <= self.minDetectionLength {
                self.detectionLength += 1
            // if speech activity is detected, continue until the maximum detection length is reached
            } else if detected && self.detectionLength > 0 && self.detectionLength <= self.maxDetectionLength {
                self.detectionLength += 1
            // a new detection
            } else if detected && !self.context.isSpeech {
                self.detectionLength += 1
                self.context.isSpeech = true
            // speech activity detection edge has been reached
            } else if !detected && self.detectionLength > 0 {
                self.detectionLength = 0
                self.context.isSpeech = false
            }
        } catch let error {
            self.context.error = VADError.processing("error occurred while vad is processing \(error.localizedDescription)")
            self.context.dispatch(.error)
        }
    }
}
