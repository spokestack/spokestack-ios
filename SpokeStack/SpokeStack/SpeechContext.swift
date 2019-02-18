//
//  SpeechContext.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/1/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public class SpeechContext: NSObject {
    
    // MARK: Public (properties)
    
    @objc public var transcript: String = ""
    
    @objc public var confidence: Float = 0.0
    
    @objc public var isActive: Bool = false
}
