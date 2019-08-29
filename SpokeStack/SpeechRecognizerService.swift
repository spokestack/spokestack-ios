//
//  SpeechRecognizerService.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/2/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

protocol SpeechRecognizerService: AnyObject {
    
    var configuration: SpeechConfiguration? { get set }
    
    var delegate: SpeechRecognizer? { get set }
    
    func startStreaming(context: SpeechContext) -> Void
    
    func stopStreaming(context: SpeechContext) -> Void
}
