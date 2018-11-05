//
//  GoogleRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class GoogleRecognizerConfiguration: RecognizerConfiguration {
    
    var host: String {
        get
        {
            return "speech.googleapis.com"
        }
    }
    
    var apiKey: String {
        get {
            return "12344"
        }
    }
    
    var enableWordTimeOffsets: Bool {
        get {
            return true
        }
    }
    
    var maxAlternatives: Int32 {
        get {
            return 30
        }
    }
    
    var singleUtterance: Bool {
        get {
            return false
        }
    }
    
    var interimResults: Bool {
        get {
            return true
        }
    }
}
