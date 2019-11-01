//
//  Error.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

public enum AudioError: Error, Equatable {
    case general(String)
    case audioSessionSetup(String)
}

public enum SpeechPipelineError: Error, Equatable {
    case illegalState(String)
}

public enum SpeechRecognizerError: Error, Equatable {
    case unknownCause(String)
    case failed(String)
}

public enum VADError: Error, Equatable {
    case invalidConfiguration(String)
    case initialization(String)
    case processing(String)
}

public enum WakewordModelError: Error, Equatable {
    case model(String)
    case process(String)
    case filter(String)
    case encode(String)
    case detect(String)
}
