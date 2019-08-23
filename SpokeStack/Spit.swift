//
//  Spit.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 8/12/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

public struct Spit {
    public static func spit(data: Data, fileName: String) {
        let filemgr = FileManager.default
        if let path = filemgr.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last?.appendingPathComponent(fileName) {
            if !filemgr.fileExists(atPath: path.path) {
                filemgr.createFile(atPath: path.path, contents: data, attributes: nil)
                print("TFLiteWakewordRecognizer spit created \(data.count) fileURL: \(path.path)")
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.write(data)
                    handle.synchronizeFile()
                } catch let error {
                    print("TFLiteWakewordRecognizer spit failed to open a handle to \(path.path) because \(error)")
                }
            } else {
                do {
                    let handle = try FileHandle(forWritingTo: path)
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.synchronizeFile()
                    print("TFLiteWakewordRecognizer spit appended \(data.count) to: \(path.path)")
                } catch let error {
                    print("TFLiteWakewordRecognizer spit failed to open a handle to \(path.path) because \(error)")
                }
            }
        } else {
            print("TFLiteWakewordRecognizer spit failed to get a URL for \(fileName)")
        }
    }
}
