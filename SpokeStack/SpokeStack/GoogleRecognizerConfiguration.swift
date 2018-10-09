//
//  GoogleRecognizerConfiguration.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public protocol GoogleRecognizerConfiguration: RecognizerConfiguration {
    
    var host: String { get }
    
    var apiKey: String { get }
    
    var enableWordTimeOffsets: Bool { get }
    
    var maxAlternatives: Int32 { get }
    
    var singleUtterance: Bool { get }
    
    var interimResults: Bool { get }
}

extension GoogleRecognizerConfiguration {
    
    public var host: String {
        return "speech.google.com"
    }
    
    public var apiKey: String {
        return "12344"
    }
    
    public var enableWordTimeOffsets: Bool {
        return true
    }
    
    public var maxAlternatives: Int32 {
        return 30
    }
    
    public var singleUtterance: Bool {
        return false
    }
    
    public var interimResults: Bool {
        return true
    }
}

