//
//  SpeechConfiguration.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class SpeechConfiguration: NSObject {
    @objc public var wakeWords: String = "marvin" // cannot contain spaces
    @objc public var wakePhrases: String = "marvin"
    public var wakeSmoothLength: Int = 50
    public var fftWindowType: SignalProcessing.FFTWindowType = .hann
    @objc public var rmsTarget: Float = 0.08
    @objc public var rmsAlpha: Float = 0.1
    @objc public var fftWindowSize: Int = 512
    @objc public var fftHopLength: Int = 10
    @objc public var melFrameLength: Int = 10 // coreml: 400, tflite: 10
    @objc public var melFrameWidth: Int = 40
    @objc public var stateWidth: Int = 128
    @objc public var encodeLength: Int = 1000
    @objc public var encodeWidth: Int = 128
    @objc public var wakeThreshold: Float = 0.9
    public var wakePhraseLength: Int = 2000
    @objc public var wakeActiveMin: Int = 600
    @objc public var wakeActiveMax: Int = 5000
    public var vadMode: VADMode = VADMode.HighQuality
    @objc public var vadFallDelay: Int = 600
    public var sampleRate = 16000
    public var languageLocale = "en-US"
    @objc public var frameWidth: Int = 20 // should be wakeFrameWidth
    @objc public var wakewordRequestTimeout: Int = 50000 // unique to iOS, not in android
    @objc public var preEmphasis: Float = 0.97
    @objc public var filterModelName: String = "Filter"
    @objc public var encodeModelName: String = "Encode"
    @objc public var detectModelName: String = "Detect"
    @objc public var filterModelPath: String = "Filter.model"
    @objc public var encodeModelPath: String = "Encode.model"
    @objc public var detectModelPath: String = "Detect.model"
    @objc public var tracing: Trace.Level = Trace.Level.NONE
}
