//
//  TranscriptEditor.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 10/7/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

///  A functional interface used to edit an ASR transcript before it is passed to the NLU module for classification.
///
/// This can be used to alter ASR results that frequently contain a spelling for a homophone that's incorrect for the domain; for example, an app used to summon a genie whose ASR transcripts tend to contain "Jen" instead of  "djinn".
@objc public protocol TranscriptEditor {
    /// Edit the ASR transcript to correct errors or perform other normalization before NLU classification occurs.
    /// - Parameter transcript:  The transcript received from the ASR module.
    /// - Returns: An edited transcript.
    @objc func editTranscript(transcript: String) -> String
}
