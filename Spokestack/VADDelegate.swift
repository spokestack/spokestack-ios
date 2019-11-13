//
//  VADDelegate.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/9/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Protocol for receiving VAD activation and error events.
@objc public protocol VADDelegate: AnyObject {
    
    /// The VAD has detected speech.
    /// - Parameter frame: The first frame of audio samples containing speech.
    func activate(frame: Data)
    
    /// The VAD has stopped detecting speech.
    func deactivate()
}
