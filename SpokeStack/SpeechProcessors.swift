//
//  SpeechProcessors.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public enum SpeechProcessors: Int {
    case appleWakeword
    case coremlWakeword
    case tFLiteWakeword
    case appleSpeech
}

extension SpeechProcessors {
    public var processor: SpeechProcessor {
        switch self {
        case .appleWakeword:
            return AppleWakewordRecognizer.sharedInstance
        case .coremlWakeword:
            return CoreMLWakewordRecognizer.sharedInstance
        case .tFLiteWakeword:
            return TFLiteWakewordRecognizer.sharedInstance
        case .appleSpeech:
            return AppleSpeechRecognizer.sharedInstance
        }
    }
}
