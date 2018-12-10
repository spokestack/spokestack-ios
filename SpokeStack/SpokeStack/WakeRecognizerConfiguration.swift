//
//  WakeRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public protocol WakeRecognizerConfiguration: RecognizerConfiguration {
    
    var wakeWords: String { get }
    
    var wakePhrases: String { get }
    
    var wakeSmoothLength: Int { get }
    
    var frameWidth: Int { get }
    
    var fftWindowType: String { get }
    
    var rmsTarget: Float { get }
    
    var rmsAlpha: Float { get }
    
    var fftWindowSize: Int { get }
    
    var fftHopLength: Int { get }
    
    var melFrameLength: Int { get }
    
    var melFrameWidth: Int { get }
    
    var wakePhraseLength: Int { get }
    
    var wakeActionMin: Int { get }
    
    var wakeActionMax: Int { get }
}

extension WakeRecognizerConfiguration {
    
    var fftWindowType: String {
        return "hann"
    }
    
    var frameWidth: Int {
        return 10
    }
    
    var rmsTarget: Float {
        return 0.08
    }
    
    var rmsAlpha: Float {
        return 0.1
    }
    
    var fftWindowSize: Int {
        return 512
    }
    
    var fftHopLength: Int {
        return 10
    }
    
    var melFrameLength: Int {
        return 400
    }
    
    var melFrameWidth: Int {
        return 40
    }
    
    var wakeSmoothLength: Int {
        return 300
    }
    
    var wakePhraseLength: Int {
        return 500
    }

    var wakeActionMin: Int {
        return 500
    }
    
    var wakeActionMax: Int {
        return 5000
    }
}
