//
//  SpeechEvents.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 8/6/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc internal enum SpeechEvents: Int {
    case initialize
    case start
    case stop
    case activate
    case deactivate
    case recognize
    case error
    case trace
    case timeout
}
