//
//  SpeechEventDelegate.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 2/22/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public protocol SpeechEventDelegate: AnyObject {
    
    @objc func onEvent(_ event: Event, context: SpeechContext) throws -> Void
}
