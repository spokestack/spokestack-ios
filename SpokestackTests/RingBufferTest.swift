//
//  RingBufferTest.swift
//  SpokestackTests
//
//  Created by Noel Weichbrodt on 8/30/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import XCTest
import Spokestack

class RingBufferTest: XCTestCase {

    func testConstructor() {
        let buffer0 = RingBuffer<Float>(0, repeating: 0.0)
        // empty buffer
        XCTAssert(buffer0.capacity == 0)
        XCTAssert(buffer0.isEmpty);
        XCTAssert(buffer0.isFull);
        
        // unit uffer
        let buffer1 = RingBuffer<Int>(1, repeating: 0)
        XCTAssert(buffer1.capacity == 1);
        XCTAssert(buffer1.isEmpty);
        XCTAssert(!buffer1.isFull);
        
        // valid buffer
        let buffer10 = RingBuffer<Double>(10, repeating: 0)
        XCTAssert(buffer10.capacity == 10);
        XCTAssert(buffer10.isEmpty);
        XCTAssert(!buffer10.isFull);
    }

    func testReadWrite() {
        
        // can't read from an empty buffer
        var thrownError: Error?
        let buffer3 = RingBuffer<Int>(3, repeating: 0)
        XCTAssertThrowsError(try buffer3.read()) { thrownError = $0 }
        XCTAssert(thrownError is RingBufferStateError, "unexpected error type \(type(of: thrownError)) during read()")
        
        // single read/write
        XCTAssertNoThrow(try buffer3.write(1))
        XCTAssert(!buffer3.isEmpty)
        XCTAssert(!buffer3.isFull)
        XCTAssertEqual(try buffer3.read(), 1)
        XCTAssert(buffer3.isEmpty)
        XCTAssert(!buffer3.isFull)
        
        // full buffer write
        for i in 0..<buffer3.capacity {
            XCTAssertNoThrow(try buffer3.write(i))
        }
        XCTAssert(!buffer3.isEmpty)
        XCTAssert(buffer3.isFull)
        
        // can't write to a full buffer
        XCTAssertThrowsError(try buffer3.write(0)) { thrownError = $0 }
        XCTAssert(thrownError is RingBufferStateError, "unexpected error type \(type(of: thrownError)) during read()")
        
        // read all the way to empty from a full buffer
        for _ in 0..<buffer3.capacity {
            XCTAssertNoThrow(try buffer3.read())
        }
        XCTAssert(buffer3.isEmpty);
        XCTAssert(!buffer3.isFull);
    }

    func testRewind() {
        let buffer4 = RingBuffer<Int>(4, repeating: 0)
        
        // default rewind
        buffer4.rewind()
        XCTAssert(!buffer4.isEmpty)
        XCTAssert(buffer4.isFull)
        while !buffer4.isEmpty {
            XCTAssertNoThrow(try buffer4.read())
        }
        
        // valid rewind
        for i in 0..<buffer4.capacity {
            XCTAssertNoThrow(try buffer4.write(i+1))
        }
        while !buffer4.isEmpty {
            XCTAssertNoThrow(try buffer4.read())
        }
        buffer4.rewind()
        XCTAssert(!buffer4.isEmpty)
        XCTAssert(buffer4.isFull)
        for _ in 0..<buffer4.capacity {
            XCTAssertNoThrow(try buffer4.read())
        }
        XCTAssert(buffer4.isEmpty);
        XCTAssert(!buffer4.isFull);
    }
    
    func testSeek() {
        let buffer5 = RingBuffer<Int>(5, repeating: 0)
        
        // valid seek
        for i in 0..<buffer5.capacity {
            XCTAssertNoThrow(try buffer5.write(i+1))
        }
        buffer5.seek(1)
        for i in 1..<buffer5.capacity {
            XCTAssertEqual(try buffer5.read(), i+1)
        }
        buffer5.rewind()
        buffer5.seek(buffer5.capacity - 1)
        for i in stride(from: buffer5.capacity - 1, to: buffer5.capacity, by: 1) {
             XCTAssertEqual(try buffer5.read(), i+1)
        }
    }
    
    func testReset() {
        let buffer6 = RingBuffer<Int>(6, repeating: 0)
        
        // reset empty
        buffer6.reset()
        XCTAssert(buffer6.isEmpty)
        XCTAssert(!buffer6.isFull)
        
        // reset valid
        for i in 0..<buffer6.capacity {
            XCTAssertNoThrow(try buffer6.write(i+1))
        }
        buffer6.reset()
        XCTAssert(buffer6.isEmpty)
        XCTAssert(!buffer6.isFull)
    }
    
    func testFill() {
        let buffer7 = RingBuffer<Int>(7, repeating: 0)

        // complete fill
        buffer7.fill(1)
        XCTAssert(!buffer7.isEmpty)
        XCTAssert(buffer7.isFull)
        for _ in 0..<buffer7.capacity {
            XCTAssertEqual(try buffer7.read(), 1)
        }
        
        // partial fill with mixed values
        buffer7.rewind()
        buffer7.seek(1)
        buffer7.fill(2)
        XCTAssert(!buffer7.isEmpty)
        XCTAssert(buffer7.isFull)
        for _ in 0..<(buffer7.capacity - 1) {
            XCTAssertEqual(try buffer7.read(), 1)
        }
        XCTAssertEqual(try buffer7.read(), 2)
    }
}
