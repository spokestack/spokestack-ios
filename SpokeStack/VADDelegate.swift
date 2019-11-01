//
//  VADDelegate.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/9/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public protocol VADDelegate: AnyObject {
    func activate(frame: Data)
    func deactivate()
}
