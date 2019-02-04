//
//  AppleWakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/4/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

public class AppleWakewordRecognizer: SpeechRecognizerService {
    static let sharedInstance: AppleSpeechRecognizer = AppleSpeechRecognizer()
    public var configuration: RecognizerConfiguration = WakewordRecognizerConfiguration()
    public weak var delegate: SpeechRecognizer?
    private var words: Array<String> = []
    private var wakeWordConfiguration: WakewordRecognizerConfiguration {
        return self.configuration as! WakewordRecognizerConfiguration
    }
    
    deinit {}
    
    public init() {
        let wakeWords: Array<String> = self.wakeWordConfiguration.wakeWords.components(separatedBy: ",")
        self.words = Array(repeating: "", count: wakeWords.count + 1)
    }
    
    func startStreaming() {
        
    }
    
    func stopStreaming() {
        
    }
}
