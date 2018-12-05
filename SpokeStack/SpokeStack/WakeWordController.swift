//
//  WakeWordController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

class WakeWordController {
    
    // MARK: Private (properties)
    
    private let wakeWordConfiguration: WakeRecognizerConfiguration
    
    private let audioController: AudioController = AudioController()
    
    // MARK: Initializers
    
    init(_ configuration: WakeRecognizerConfiguration) {
        self.wakeWordConfiguration = configuration
    }
    
    // MARK: Internal (methods)
    
    func activate() -> Void {
        
    }
    
    func deactivate() -> Void {
        
    }
}
