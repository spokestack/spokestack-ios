//
//  SFSpeechRecognitionResult+Extensions.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 2/13/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Speech

extension SFSpeechRecognitionResult {
    
    // MARK: Properties (internal)
    
    var spstk_confidence: Float {
        
        let confidence = self.transcriptions.first?.segments.sorted(by: { (a, b) -> Bool in
                a.confidence <= b.confidence
        }).first?.confidence ?? 0.0
        
        return confidence
    }
}
