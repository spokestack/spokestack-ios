//
//  SampleWakeRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

struct SampleWakeRecognizerConfiguration: WakeRecognizerConfiguration {
    
    var wakeWords: String {
        return "up, dog"
    }
    
    var wakePhrases: String {
        return "up dog"
    }
}
