//
//  NLUDelegate.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 2/14/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Protocol for receiving events from the NLU service.
@objc public protocol NLUDelegate: AnyObject, Tracer {
    
    /// The NLU classifier has produced a result.
    /// - Parameter result: The result of NLU classification.
    @objc optional func classification(result: NLUResult) -> Void
    
    /// The NLU classification request has resulted in an error response.
    /// - Parameter error: The error representing the NLU response.
    @objc optional func failure(nluError: Error) -> Void
}
