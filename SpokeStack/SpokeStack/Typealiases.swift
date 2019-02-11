//
//  Typealiases.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

typealias TwoDimensionArray<T> = Array<Array<T>>
typealias ThreeDimensionArray<T> = Array<TwoDimensionArray<T>>

public typealias SpeechRecognitionClosure<T> = (_ result: SPSpeechRecognitionResult<T, SPSpeechRecognitionError>) -> Void
