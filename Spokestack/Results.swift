//
//  Results.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// CloudKit

public enum SPSpeechRecognitionError: Error {
    case general(String)
    case emptyresult(String)
}

public enum SPSpeechRecognitionResult<T, ResultError: Error> {
    case success(T)
    case failure(ResultError)
}
