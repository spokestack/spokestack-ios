//
//  GoogleRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class GoogleRecognizerConfiguration: RecognizerConfiguration {
    
    @objc public var host = "speech.googleapis.com"
    
    @objc public var apiKey = "REPLACE_ME"
    
    @objc public var enableWordTimeOffsets = true
    
    @objc public var maxAlternatives: Int32 = 30
    
    @objc public var singleUtterance = false
    
    @objc public var interimResults = true
}

