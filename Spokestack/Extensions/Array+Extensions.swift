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
    
    /// Returns the index and value of the largest number in the array.
    public func argmax() -> (Int, Float) {
        var maxValue: Float = 0.0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(self, 1, &maxValue, &maxIndex, vDSP_Length(self.count))
        return (Int(maxIndex), maxValue)
    }
}

extension Array where Element == Foundation.NSObject.Type {
    
    /// Assert that each element, in order, of this array and the other array are the same type
    /// - Parameter other: The array of instances to check types against
    /// - Returns: True if both arrays contain elements of the same type, in order.
    public func areSameOrderedType(other: [Any]) -> Bool {
        for (i, o) in other.enumerated() {
            if !(self[i] == type(of: o).self) { return false }
        }
        return true
    }
}
