//
//  Spit.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 8/12/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

public struct Trace {
    @objc public enum Level: Int {
        case NONE = 100
        case INFO = 30
        case PERF = 20
        case DEBUG = 10
    }
    
    public static func trace(_ level: Trace.Level, configLevel: Trace.Level, message: String, delegate: SpeechEventListener?, caller: Any) {
        if level.rawValue >= configLevel.rawValue {
            delegate?.didTrace("\(level) \(String(describing: type(of: caller))) \(message)")
        }
    }

    public static func trace(_ level: Trace.Level, configLevel: Trace.Level, message: String, delegate: PipelineDelegate?, caller: Any) {
        if level.rawValue >= configLevel.rawValue {
            delegate?.didTrace("\(level) \(String(describing: type(of: caller))) \(message)")
        }
    }
    
    public static func spit(data: Data, fileName: String, delegate: SpeechEventListener) {
        let filemgr = FileManager.default
        if let path = filemgr.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last?.appendingPathComponent(fileName) {
            if !filemgr.fileExists(atPath: path.path) {
                filemgr.createFile(atPath: path.path, contents: data, attributes: nil)
                delegate.didTrace("Trace spit created \(data.count) fileURL: \(path.path)")
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.write(data)
                    handle.synchronizeFile()
                } catch let error {
                    delegate.didTrace("Trace spit failed to open a handle to \(path.path) because \(error)")
                }
            } else {
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.synchronizeFile()
                    delegate.didTrace("Trace spit appended \(data.count) to: \(path.path)")
                } catch let error {
                    delegate.didTrace("Trace spit failed to open a handle to \(path.path) because \(error)")
                }
            }
        } else {
            delegate.didTrace("Trace spit failed to get a URL for \(fileName)")
        }
    }
}
