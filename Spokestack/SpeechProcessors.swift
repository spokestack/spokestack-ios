//
//  SpeechProcessors.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Convenience enum for the singletons of the different implementers of the `SpeechProcessor` protocol.
@objc public enum SpeechProcessors: Int {
    /// AppleWakewordRecognizer
    case appleWakeword
    /// CoreMLWakewordRecognizer
    case coremlWakeword
    /// TFLiteWakewordRecognizer
    case tfLiteWakeword
    /// AppleSpeechRecognizer
    case appleSpeech
}

extension SpeechProcessors {
    /// Convenience property accessor for the singletons of the different implementers of the `SpeechProcessor` protocol
    /// - Returns: singleton instance of the specified `SpeechProcessor`
    public var processor: SpeechProcessor {
        switch self {
        case .appleWakeword:
            return AppleWakewordRecognizer.sharedInstance
        case .coremlWakeword:
            return CoreMLWakewordRecognizer.sharedInstance
        case .tfLiteWakeword:
            return TFLiteWakewordRecognizer.sharedInstance
        case .appleSpeech:
            return AppleSpeechRecognizer.sharedInstance
        }
    }
}
