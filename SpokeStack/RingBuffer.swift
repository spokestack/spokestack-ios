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

final class RingBuffer <T> {

    // MARK: Public (properties)
    
    var capacity: Int {
        return self.data.count - 1
    }
    
    var available: Int {
        return self.wpos - self.rpos
    }
    
    var isEmpty: Bool {
        return self.rpos == self.wpos
    }
    
    var isFull: Bool {
        return self.pos(self.wpos + 1) == self.rpos
    }
    
    // MARK: Private (properties)
    
    private var data: ContiguousArray<T> = []
    private var rpos: Int = 0
    private var wpos: Int = 0
    
    // MARK: Initializers
    
    required init(_ capacity: Int, repeating: T) {
        let reservedCapacity: Int = capacity + 1
        self.data = ContiguousArray(repeating: repeating, count: reservedCapacity)
    }
    
    // MARK: Public (methods)
    
    @discardableResult
    func rewind() -> RingBuffer {
        self.rpos = self.pos(self.wpos + 1)
        return self
    }
    
    @discardableResult
    func seek(_ elems: Int) -> RingBuffer {
        self.rpos = self.pos(self.rpos + elems)
        return self
    }
    
    @discardableResult
    func reset() -> RingBuffer {
        self.rpos = self.wpos
        return self
    }
    
    func read() throws -> T {
        if self.isEmpty {
            throw RingBufferStateError.illegalState(message: "ring buffer is empty")
        }
        let value: T = self.data[self.rpos]
        self.rpos = self.pos(self.rpos + 1)
        return value
    }
    
    func write(_ value: T) throws -> Void {
        if self.isFull {
            throw RingBufferStateError.illegalState(message: "ring buffer is full")
        }
        self.data[self.wpos] = value
        self.wpos = self.pos(self.wpos + 1)
    }
    
    @discardableResult
    func fill(_ value: T) -> RingBuffer {
        while !self.isFull {
            try! self.write(value)
        }
        return self
    }
    
    // MARK: Private (properties)
    
    private func pos(_ x: Int) -> Int {
        let c = self.data.count
        let pos = x - self.data.count * Int(floor(Double(x / self.data.count)))
        return pos
    }
}
