//
//  VADTrigger.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/7/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc public class VADTrigger: NSObject, SpeechProcessor {
    @objc public var configuration: SpeechConfiguration
    
    @objc public var context: SpeechContext
    
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
    }
    
    @objc public func startStreaming() {}
    
    @objc public func stopStreaming() {}
    
    @objc public func process(_ frame: Data) {
        if self.context.isSpeech && !self.context.isActive {
            self.context.isActive = true
            self.context.dispatch(.activate)
        }
    }
    
    
}
