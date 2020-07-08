//
//  VADTrigger.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/7/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc public class VADTrigger: NSObject, SpeechProcessor {
    public var configuration: SpeechConfiguration
    
    public var context: SpeechContext
    
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        super.init()
    }
    
    public func startStreaming() {}
    
    public func stopStreaming() {}
    
    public func process(_ frame: Data) {
        if self.context.isSpeech && !self.context.isActive {
            self.context.isActive = true
            self.configuration.delegateDispatchQueue.async {
                self.context.listeners.forEach { listener in
                    listener.didActivate()
                }
            }
        } else if !self.context.isSpeech && self.context.isActive {
//            self.context.isActive = false
        }
    }
    
    
}
