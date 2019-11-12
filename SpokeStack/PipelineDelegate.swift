//
//  PipelineDelegate.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 3/21/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Protocol for delegates to receive pipeline events.
@objc public protocol PipelineDelegate {
    
    /// The speech pipeline has been initialized.
    func didInit() -> Void
    
    /// The speech pipeline has been started.
    func didStart() -> Void
    
    /// The speech pipeline has been stopped.
    func didStop() -> Void
    
    /// The speech pipeline encountered an error during initialization.
    /// - Parameter error: A human-readable error message.
    func setupFailed(_ error: String) -> Void
    
    /// A trace event from the speech pipeline.
    /// - Parameter trace: The debugging trace message.
    func didTrace(_ trace: String) -> Void
}
