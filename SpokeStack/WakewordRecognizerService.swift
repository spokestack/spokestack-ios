//
//  WakewordRecognizerService.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

protocol WakewordRecognizerService: AnyObject {
    
    var configuration: SpeechConfiguration? { get set }
    
    var delegate: WakewordRecognizer? { get set }
    
    func startStreaming(context: SpeechContext) -> Void
    
    func stopStreaming(context: SpeechContext) -> Void
}
