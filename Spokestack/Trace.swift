//
//  Spit.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 8/12/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Debugging trace levels, for simple filtering.
public struct Trace {
    @objc public enum Level: Int {
        /// No traces
        case NONE = 100
        /// Informational traces
        case INFO = 30
        /// Performance traces
        case PERF = 20
        /// All the traces
        case DEBUG = 10
    }
    
    /// Traces a  debugging message.
    /// - Parameter level: The debugging trace level for this message.
    /// - Parameter configLevel: The speech pipeline's configured debugging trace level.
    /// - Parameter message: The debugging trace message.
    /// - Parameter delegate: The delegate that should receive the debugging trace message.
    /// - Parameter caller: The sender of the debugging trace message.
    public static func trace(_ level: Trace.Level, configLevel: Trace.Level, message: String, delegate: SpeechEventListener?, caller: Any) {
        if level.rawValue <= configLevel.rawValue {
            delegate?.didTrace("\(level.rawValue) \(String(describing: type(of: caller))) \(message)")
        }
    }
    
    /// Traces a debugging message.
    /// - Parameter level: The debugging trace level for this message.
    /// - Parameter configLevel: The speech pipeline's configured debugging trace level.
    /// - Parameter message: The debugging trace message.
    /// - Parameter delegate: The delegate that should receive the debugging trace message.
    /// - Parameter caller: The sender of the debugging trace message.
    public static func trace(_ level: Trace.Level, configLevel: Trace.Level, message: String, delegate: PipelineDelegate?, caller: Any) {
        if level.rawValue <= configLevel.rawValue {
            delegate?.didTrace("\(level.rawValue) \(String(describing: type(of: caller))) \(message)")
        }
    }
    
    /// Traces a debugging message.
    /// - Parameter level: The debugging trace level for this message.
    /// - Parameter configLevel: The speech pipeline's configured debugging trace level.
    /// - Parameter message: The debugging trace message.
    /// - Parameter delegate: The delegate that should receive the debugging trace message.
    /// - Parameter caller: The sender of the debugging trace message.
    public static func trace(_ level: Trace.Level, configLevel: Trace.Level, message: String, delegate: TextToSpeechDelegate?, caller: Any) {
        if level.rawValue <= configLevel.rawValue {
            delegate?.didTrace("\(level.rawValue) \(String(describing: type(of: caller))) \(message)")
        }
    }
    
    /// Write data to a file, after clojure/core's `spit`.
    /// - Parameter data: The data to write to the file.
    /// - Parameter fileName: The name of the file that will be created/appended with the data.
    /// - Parameter delegate: The delegate that should receive the debugging trace message with the spit results.
    /// - Note: https://clojuredocs.org/clojure.core/spit
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
