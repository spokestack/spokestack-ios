//
//  WakewordService.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 2/13/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

public enum WakewordService {
    case appleWakeword, wakeword
}

extension WakewordService {
    
    var wakewordRecognizerService: WakewordRecognizerService {
        
        switch self {
        case .appleWakeword:
            return AppleWakewordRecognizer.sharedInstance
        case .wakeword
            return WakeWordSpeechRecognizer.sharedInstance
        }
    }
}
