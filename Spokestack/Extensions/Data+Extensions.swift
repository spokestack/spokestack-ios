//
//  Data+Extensions.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 12/26/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

extension Data {
    func elements<T>() -> [T] {
        return withUnsafeBytes {
            Array(UnsafeBufferPointer(start: $0.bindMemory(to: T.self).baseAddress, count: count/MemoryLayout<T>.size))
        }
    }
    
    func toArray<T>(type: T.Type, count: Int) -> [T] where T: ExpressibleByIntegerLiteral {
        return self.withUnsafeBytes({ (pointer: UnsafeRawBufferPointer) -> [T] in
            Array<T>(UnsafeBufferPointer(start: pointer.bindMemory(to: T.self).baseAddress, count: count))
        })
    }
}
