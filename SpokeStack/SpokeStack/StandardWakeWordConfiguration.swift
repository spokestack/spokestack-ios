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
        return "up,dog,break,yo,self,fool"
    }
    
    var wakePhrases: String {
        return "up dog,break yo self fool"
    }
}
