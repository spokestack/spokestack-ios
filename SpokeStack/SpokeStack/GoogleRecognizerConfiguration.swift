//
//  GoogleRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class GoogleRecognizerConfiguration: RecognizerConfiguration {
    
    var host = "speech.googleapis.com"
    var apiKey = "12344"
    var enableWordTimeOffsets = true
    var maxAlternatives: Int32 = 30
    var singleUtterance = false
    var interimResults = true
}
