//
//  VADTriggerTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 9/23/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import XCTest
import Spokestack

class VADTriggerTest: XCTestCase {
    func testEverything() {
        let config = SpeechConfiguration()
        let context = SpeechContext(config)
        let vt = VADTrigger(config, context: context)
        vt.startStreaming()
        vt.stopStreaming()
        context.isSpeech = true
        context.isActive = false
        vt.process(Frame.voice(frameWidth: 20, sampleRate: 8000))
        XCTAssert(context.isActive)
    }
}
