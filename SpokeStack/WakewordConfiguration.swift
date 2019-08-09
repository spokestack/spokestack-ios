//
//  WakeRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class WakewordConfiguration: NSObject {
    @objc public var wakeWords: String = "up,dog" // cannot contain spaces
    @objc public var wakePhrases: String = "up dog"
    public var wakeSmoothLength: Int = 50
    public var fftWindowType: String = "hann"
    public var rmsTarget: Float = 0.08
    public var rmsAlpha: Float = 0.1
    public var fftWindowSize: Int = 512
    public var fftHopLength: Int = 10
    public var melFrameLength: Int = 10 // coreml: 400, tflite: 10
    public var melFrameWidth: Int = 40
    public var stateWidth: Int = 128
    public var encodeLength: Int = 1000
    public var encodeWidth: Int = 128
    public var wakeThreshold: Float = 0.5
    public var wakePhraseLength: Int = 2000
    public var wakeActiveMin: Int = 600
    public var wakeActiveMax: Int = 5000
    public var sampleRate = 16000
    public var languageLocale = "en-US"
    public var frameWidth: Int = 20
    public var wakewordRequestTimeout: Int = 50000
    public var preEmphasis: Float = 0.97
    public var filterModel: String = "filter"
    public var encodeModel: String = "encode"
    public var detectModel: String = "detect"
}
