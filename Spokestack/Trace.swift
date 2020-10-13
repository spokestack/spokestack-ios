//
//  Spit.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 8/12/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
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
    
    /// Traces a  message  from a Spokestack module.
    /// - Parameter level: The debugging trace level for this message.
    /// - Parameter config: The Spokestack configuration.
    /// - Parameter message: The debugging trace message.
    /// - Parameter delegate: The delegate that should receive the debugging trace message.
    /// - Parameter context: The context of the speech pipeline.
    /// - Parameter caller: The sender of the debugging trace message.
    public static func trace(_ level: Trace.Level, message: String, config: SpeechConfiguration?, context: SpeechContext?, caller: Any) {
        if level.rawValue >= config?.tracing.rawValue ?? Level.DEBUG.rawValue {
            context?.dispatch { $0.didTrace?("\(level.rawValue) \(String(describing: type(of: caller))) \(message)") }
        }
    }
    
    /// Traces a message from a Spokestack module.
    /// - Parameter level: The trace level for this message.
    /// - Parameter config: The Spokestack configuration.
    /// - Parameter message: The debugging trace message.
    /// - Parameter delegates: The delegates that should receive the trace message.
    /// - Parameter caller: The sender of the trace message.
    public static func trace(_ level: Trace.Level, message: String, config: SpeechConfiguration, delegates: [Tracer], caller: Any)  {
        if level.rawValue >= config.tracing.rawValue {
            config.delegateDispatchQueue.async {
                delegates.forEach {
                $0.didTrace?("\(level.rawValue) \(String(describing: type(of: caller))) \(message)")
                }
            }
        }
    }
    
    /// Write data to a file, after clojure/core's `spit`.
    /// - Parameter data: The data to write to the file.
    /// - Parameter fileName: The name of the file that will be created/appended with the data.
    /// - Parameter delegate: The delegate that should receive the debugging trace message with the spit results.
    /// - Parameter context: The context of the speech pipeline.
    /// - Parameter config: The Spokestack configuration.
    /// - Note: https://clojuredocs.org/clojure.core/spit
    public static func spit(data: Data, fileName: String, context: SpeechContext?, config: SpeechConfiguration?) {
        let filemgr = FileManager.default
        if let path = filemgr.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last?.appendingPathComponent(fileName) {
            if !filemgr.fileExists(atPath: path.path) {
                filemgr.createFile(atPath: path.path, contents: data, attributes: nil)
                context?.dispatch { $0.didTrace?("Trace spit created \(data.count) fileURL: \(path.path)") }
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.write(data)
                    handle.synchronizeFile()
                } catch let error {
                    context?.dispatch { $0.didTrace?("Trace spit failed to open a handle to \(path.path) because \(error)") }
                }
            } else {
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.synchronizeFile()
                } catch let error {
                    context?.dispatch { $0.didTrace?("Trace spit failed to open a handle to \(path.path) because \(error)") }
                }
            }
        } else {
            context?.dispatch { $0.didTrace?("Trace spit failed to get a URL for \(fileName)") }
        }
    }
}
