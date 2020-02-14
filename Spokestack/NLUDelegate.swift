//
//  NLUDelegate.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/14/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Protocol for receiving events from the NLU service.
@objc public protocol NLUDelegate: AnyObject {
    
    /// The NLU classifier has produced a result.
    /// - Parameter result: The result of NLU classification.
    func classification(result: NLUResult) -> Void
    
    /// A trace event from the NLU system.
    /// - Parameter trace: The debugging trace message.
    func didTrace(_ trace: String) -> Void
    
    /// The NLU classification request has resulted in an error response.
    /// - Parameter error: The error representing the NLU response.
    func failure(error: Error) -> Void
}
