//
//  RecognizerService.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public enum RecognizerService {
    case googleSpeech, appleSpeech
}

extension RecognizerService {
    
    var speechRecognizerService: SpeechRecognizerService {
        
        switch self {
        case .googleSpeech:
            return GoogleSpeechRecognizer.sharedInstance
        case .appleSpeech:
            return AppleSpeechRecognizer.sharedInstance
        }
    }
}
