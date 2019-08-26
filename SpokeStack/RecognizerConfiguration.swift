//
//  RecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class RecognizerConfiguration: NSObject {
    
    public var sampleRate = 16000
    public var languageLocale = "en-US"
    public var frameWidth: Int = 10
    @objc public var vadFallDelay: Int = 600
    @objc public var wakeActiveMax: Int = 5000
    public var tracing: Trace.Level = Trace.Level.NONE
}
