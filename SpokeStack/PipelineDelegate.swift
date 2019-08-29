//
//  SpeechPipelineService.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 3/21/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public protocol PipelineDelegate {

    func didInit() -> Void
    
    func didStart() -> Void

    func didStop() -> Void
    
    func setupFailed(_ error: String) -> Void
    
    func didTrace(_ trace: String) -> Void
}
