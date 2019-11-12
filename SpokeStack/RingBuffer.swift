//
//  RingBuffer.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 12/5/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// A simple circular buffer of values.
final class RingBuffer <T> {

    // MARK: Public (properties)
    
    /// The number of empty spaces remaining in the RingBuffer until it's full.
    var capacity: Int {
        return self.data.count - 1
    }
    
    /// Is the RingBuffer empty?
    var isEmpty: Bool {
        return self.rpos == self.wpos
    }
    
    /// Is the RingBuffer full?
    var isFull: Bool {
        return self.pos(self.wpos + 1) == self.rpos
    }
    
    /// Internal state information for debugging purposes
    /// - Returns: A string representation of internal RingBuffer state.
    func debug() -> String {
        return ("RingBuffer \(self.data.count) \(self.wpos) \(self.rpos)")
    }
    
    // MARK: Private (properties)
    
    private var data: ContiguousArray<T> = []
    private var rpos: Int = 0
    private var wpos: Int = 0
    
    // MARK: Initializers
    
    ///  Constructs a new instance.
    /// - Parameter capacity: The maximum number of elements to store.
    /// - Parameter repeating: Initial value for all buffer elements.
    required init(_ capacity: Int, repeating: T) {
        let reservedCapacity: Int = capacity + 1
        self.data = ContiguousArray(repeating: repeating, count: reservedCapacity)
    }
    
    // MARK: Public (methods)
    
    /// Seeks the read head to the beginning, marking it full and allowing all elements to be read.
    @discardableResult
    func rewind() -> RingBuffer {
        self.rpos = self.pos(self.wpos + 1)
        return self
    }
    
    /// Seeks the read head forward.
    ///
    /// Care must be taken by the caller to avoid read overflow.
    /// - Parameter elems: The number of elements to move forward/backward.
    @discardableResult
    func seek(_ elems: Int) -> RingBuffer {
        self.rpos = self.pos(self.rpos + elems)
        return self
    }
    
    /// Resets the read head of the buffer, marking the buffer empty, but not modifying any elements.
    @discardableResult
    func reset() -> RingBuffer {
        self.rpos = self.wpos
        return self
    }
    
    /// Reads the next value from the buffer.
    /// - Throws: RingBufferStateError.illegalState if a read is performed when the RingBuffer is empty.
    func read() throws -> T {
        if self.isEmpty {
            throw RingBufferStateError.illegalState(message: "ring buffer is empty")
        }
        let value: T = self.data[self.rpos]
        self.rpos = self.pos(self.rpos + 1)
        return value
    }
    
    /// Writes the next value to the buffer.
    /// - Parameter value: The value to write.
    /// - Throws: RingBufferStateError.illegalState if a write is performed when the RingBuffer is full.
    func write(_ value: T) throws -> Void {
        if self.isFull {
            throw RingBufferStateError.illegalState(message: "ring buffer is full")
        }
        self.data[self.wpos] = value
        self.wpos = self.pos(self.wpos + 1)
    }
    
    /// Fills the remaining positions in the buffer with the specified value.
    /// - Parameter value: The value to write.
    @discardableResult
    func fill(_ value: T) -> RingBuffer {
        while !self.isFull {
            try! self.write(value)
        }
        return self
    }
    
    // MARK: Private (properties)
    
    private func pos(_ x: Int) -> Int {
        return x - self.data.count * Int(floor(Double(x / self.data.count)))
    }
}
