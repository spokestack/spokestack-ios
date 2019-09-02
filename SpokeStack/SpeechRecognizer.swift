//
//  SpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/1/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public protocol SpeechRecognizer: AnyObject {
        
    func didRecognize(_ result: SpeechContext) -> Void
    
    func deactivate() -> Void
    
    func didError(_ error: Error) -> Void
    
    func timeout() -> Void
    
    func didTrace(_ trace: String) -> Void
}
