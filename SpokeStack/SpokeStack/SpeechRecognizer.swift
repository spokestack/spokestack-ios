//
//  SpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/1/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public protocol SpeechRecognizer: AnyObject {
    
    func didStart() -> Void
    
    func didRecognize(_ result: SpeechContext) -> Void
    
    func didFinish(_ error: Error?) -> Void
    
    func didError(_ error: Error) -> Void
}
