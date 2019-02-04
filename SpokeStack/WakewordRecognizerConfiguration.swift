//
//  WakeRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class WakewordRecognizerConfiguration: RecognizerConfiguration {
    
    public var wakeWords: String = "up, dog"
    
    public var wakePhrases: String = "up dog"
    
    public var wakeSmoothLength: Int = 300
    
    public var frameWidth: Int = 10
    
    public var fftWindowType: String = "hann"
    
    public var rmsTarget: Float = 0.08
    
    public var rmsAlpha: Float = 0.1
    
    public var fftWindowSize: Int = 512
    
    public var fftHopLength: Int = 10
    
    public var melFrameLength: Int = 400
    
    public var melFrameWidth: Int = 40
    
    public var wakePhraseLength: Int = 500
    
    public var wakeActionMin: Int = 500
    
    public var wakeActionMax: Int = 5000
}
