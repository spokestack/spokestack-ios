//
//  Array+Extensions.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 1/28/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Accelerate

extension Array where Element == Float {
    public func argmax() -> (Int, Float) {
        var maxValue: Float = 0.0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(self, 1, &maxValue, &maxIndex, vDSP_Length(self.count))
        return (Int(maxIndex), maxValue)
    }
}
