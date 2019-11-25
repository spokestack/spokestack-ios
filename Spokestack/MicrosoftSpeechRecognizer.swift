//
//  MicrosoftSpeechRecognizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 11/22/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation


@objc public class MicrosoftSpeechRecognizer: NSObject, SpeechProcessor {
    
    @objc public static let sharedInstance: MicrosoftSpeechRecognizer = MicrosoftSpeechRecognizer()
    
    public var configuration: SpeechConfiguration?
    
    public weak var delegate: SpeechEventListener?
    
    public var context: SpeechContext = SpeechContext()
    
    deinit {
        self.delegate = nil
    }
    
    override init() {
        super.init()
    }
    
    public func startStreaming(context: SpeechContext) {
        let config = SPXSpeechConfiguration
    }
    
    public func stopStreaming(context: SpeechContext) {
        
    }
    
    
}
