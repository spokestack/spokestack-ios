//
//  AudioControllerDelegate.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Receives audio frames from the AudioController's stream.
/// - SeeAlso: AudioController
protocol AudioControllerDelegate: AnyObject {
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    /// - Parameter frame: Audio frame of samples.
    func process(_ frame: Data) -> Void
}
