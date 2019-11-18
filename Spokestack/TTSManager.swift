//
//  TTSManager.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 11/15/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

enum TTSInputType {
    case text
    case ssml
}

class TTSManager: NSObject {


    func request() -> Void {
        
    }
    
    func request(voice: String, input: String, inputType: TTSInputType, key: String) -> String? {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var request = URLRequest(url: URL(string: "https://core.pylon.com/speech/v1/tts/synthesize")!)
        var r: String?
        request.addValue(key, forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        let body = ["voice": voice,
                    "text": input]
        request.httpBody =  try? JSONSerialization.data(withJSONObject: body, options: [])
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) -> Void in
            if let data = data {
                r = String(data: data, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
            }
            if let error = error {
                print(error)
            }
        }
        task.resume()
        print("TTSManager request task \(task.state) \(task.progress) \(String(describing: task.response)) \(String(describing: task.error))")
        return r
    }
        
    func request() -> String? {
        self.request(voice: "demo-male", input: "Here I am, a brain the size of a planet", inputType: .ssml, key: "Key f854fbf30a5f40c189ecb1b38bc78059")
    }
    
    func play(_ url: String) {
        
    }
}

extension TTSManager:  URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    
}
