//
//  SpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/1/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import googleapis

public protocol SpeechRecognizer: AnyObject {
    
    func didStart() -> Void
    
    func didRecognize(_ result: SPSpeechContext) -> Void
    
    func didFinish() -> Void
    
    ////
    
    func didFindResults(_ result: String) -> Void
    
    func setupFailed() -> Void
    
    func streamingDidStart() -> Void
    
    func beginAnalyzing() -> Void
    
    func didHaveConfiguration(_ configuration: RecognizerConfiguration) -> Void
    
    func didFindResultsButNotFinal() -> Void
    
    func didWriteInital(_ request: StreamingRecognizeRequest) -> Void
    
    func didWriteSteamingAudioContent(_ request: StreamingRecognizeRequest) -> Void
}
