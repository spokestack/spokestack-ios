//
//  RecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class RecognizerConfiguration: NSObject {
    
    public var sampleRate: Int = 16000
    
    public var languageLocale: String = "en-US"
    
    public var frameWidth: Int = 10
    
    public var vadFallDelay: Int = 600
}
