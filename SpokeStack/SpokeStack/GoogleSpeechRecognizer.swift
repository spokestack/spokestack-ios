//
//  GoogleSpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import googleapis

public class GoogleSpeechRecognizer: GoogleRecognizerConfiguration {
    
    // MARK: Public (properties)
    
    public static let sharedInstance: GoogleSpeechRecognizer = GoogleSpeechRecognizer()
    
    public var host: String = GoogleSpeechRecognizer.defaultHost
    
    public var apiKey: String = "REPLACE_ME"
    
    // MARK: Private (properties)
    
    private static let defaultHost: String = "speech.googleapis.com"
    
    private var streaming: Bool = false
    
    private var client: Speech!
    
    private var writer: GRXBufferedPipe!
    
    private var call: GRPCProtoCall!
    
    // MARK: Initializers
    
    public init() {
        AudioController.shared.delegate = self
    }
    
    // MARK: Public (methods)
    
    public func startStreaming() -> Void {
        
    }
    
    public func stopStreaming() -> Void {
        
    }
}

extension GoogleSpeechRecognizer: AudioControllerDelegate {
    
    func processSampleData(_ data: Data) -> Void {
        
    }
}
