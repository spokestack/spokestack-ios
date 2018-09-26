//
//  Results.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// CloudKit

public enum SpeechRecognitionError: Error {
    case general(String)
    case emptyresult(String)
}

public enum SpeechRecognitionResult<T, ResultError: Error> {
    case success(T)
    case failure(ResultError)
}
