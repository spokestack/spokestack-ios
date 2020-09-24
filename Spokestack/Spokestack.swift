//
//  Spokestack.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 9/23/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc public class Spokestack: NSObject {
    @objc public var pipeline: SpeechPipeline?
    @objc public var tts: TextToSpeech?
    @objc public var nlu: NLUTensorflow?
    @objc public var context: SpeechContext?
    @objc public var configuration: SpeechConfiguration?
    private var delegates: [SpokestackDelegate] = []
}

@objc public class SpokestackBuilder: NSObject {
    private var pipeline: SpeechPipeline?
    private var tts: TextToSpeech?
    private var nlu: NLUTensorflow?
    private var delegates: [SpokestackDelegate] = []
    private var config = SpeechConfiguration()
    private var context: SpeechContext
    private var pipelineProfile: SpeechPipelineProfiles = .tfLiteWakewordAppleSpeech
    
    @objc public override init() {
        self.context = SpeechContext(self.config)
        super.init()
    }
    
    @objc public func addDelegate(_ delegate: SpokestackDelegate) -> SpokestackBuilder {
        self.delegates.append(delegate)
        return self
    }
    
    @objc public func build() throws {
        let pipelineBuilder = SpeechPipelineBuilder.init()
        self.delegates.forEach { let _ = pipelineBuilder.addListener($0) }
        self.pipeline = try pipelineBuilder.useProfile(self.pipelineProfile)
            .build()
        self.tts = try TextToSpeech(self.delegates, configuration: config)
        self.nlu = try NLUTensorflow(self.delegates, configuration: config)
    }
}
