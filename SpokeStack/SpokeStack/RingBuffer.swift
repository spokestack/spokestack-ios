//
//  RingBuffer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 12/5/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

enum RingBufferStateError: Error {
    case illegalState(message: String)
}

final class RingBuffer {
    
    // MARK: Public (properties)
    
    var capacity: Int {
        return self.data.count - 1
    }
    
    var isEmpty: Bool {
        return self.rpos == self.wpos
    }
    
    var isFull: Bool {
        return self.pos(self.wpos + 1) == self.rpos
    }
    
    // MARK: Private (properties)
    
    private var data: Array<Float> = []
    
    private var rpos: Int = 0
    
    private var wpos: Int = 0
    
    // MARK: Initializers
    
    required init(_ capacity: Int) {
        
        let reservedCapacity: Int = capacity + 1
        self.data.reserveCapacity(reservedCapacity)
    }
    
    // MARK: Public (methods)
    
    func rewind() -> RingBuffer {
        
        self.rpos = self.pos(self.wpos + 1)
        return self
    }
    
    func seek(_ elems: Int) -> RingBuffer {
        
        self.rpos = self.pos(self.rpos + elems)
        return self
    }

    func reset() -> RingBuffer {
        
        self.rpos = self.wpos
        return self
    }

    func fill(_ value: Float) -> RingBuffer {
        
        while !self.isFull {
            self.write(value)
        }
    }
    
    func read() throws -> Float {
        
        if self.isEmpty {
            throw RingBufferStateError.illegalState(message: "ring buffer is empty")
        }
        
        let value: Float = self.data[self.rpos]
        self.rpos = self.pos(self.rpos + 1)
        
        return value
    }

    func write(_ value: Float) -> Void {
        
        if self.isFull {
            throw RingBufferStateError.illegalState(message: "ring buffer is full")
        }
        
        self.data[self.wpos] = value
        self.wpos = self.pos(self.wpos + 1)
    }
    
    func fill(_ value: Float) -> RingBuffer {
        
        while !self.isFull {
            self.write(value)
        }
        
        return self
    }
    
    // MARK: Private (properties)

    private func pos(_ x: Int) -> Int {
        return x % self.data.count
    }
}
