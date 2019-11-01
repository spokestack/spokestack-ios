//
//  SpeechProcessor.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public protocol SpeechProcessor: AnyObject {
    
    var configuration: SpeechConfiguration? { get set }
    
    var delegate: SpeechEventListener? { get set }
    
    var context: SpeechContext { get set }

    func startStreaming(context: SpeechContext) -> Void
    
    func stopStreaming(context: SpeechContext) -> Void
}
