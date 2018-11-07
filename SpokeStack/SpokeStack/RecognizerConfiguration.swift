//
//  RecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class RecognizerConfiguration: NSObject {
    
    var sampleRate: Int {
        get {
            return  16000
        }
    }
    
    var languageLocale: String {
        get {
            return "en-US"
        }
    }
}
