//
//  Tracer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 9/24/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

@objc public protocol Tracer {
    
    /// The debug trace event.
    /// - Parameter trace: The debugging trace message.
    @objc optional func didTrace(_ trace: String) -> Void
    
}
