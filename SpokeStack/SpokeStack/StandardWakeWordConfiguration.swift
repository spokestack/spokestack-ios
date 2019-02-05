//
//  StandardWakeWordConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 1/10/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

struct StandardWakeWordConfiguration: WakeRecognizerConfiguration {
    
    var wakeWords: String {
        return "hello,world"
    }
    
    var wakePhrases: String {
        return "hello world"
    }
}
