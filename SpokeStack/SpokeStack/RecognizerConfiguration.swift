//
//  RecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public protocol RecognizerConfiguration {
    
    var sampleRate: Int { get }
}

extension RecognizerConfiguration {
    
    public var sampleRate: Int {
        return 16000
    }
}
