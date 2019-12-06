//
//  TextToSpeech.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 11/15/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public enum TTSInputFormat: Int {
    case text
    case ssml
}

@objc public class TextToSpeech: NSObject {
    
    // MARK: Properties
    
    weak public var delegate: TextToSpeechDelegate?
    private var configuration: SpeechConfiguration
    
    // MARK: Initializers
    
    /// Initializes a new text to speech instance.
    /// - Parameter delegate: Delegate that receives text to speech events.
    /// - Parameter configuration: Speech configuration parameters.
    @objc public init(_ delegate: TextToSpeechDelegate, configuration: SpeechConfiguration) {
        self.delegate = delegate
        self.configuration = configuration
        super.init()
    }
    
    // MARK: Public Functions
    
    /// Synthesize speech using the provided input parameters and speech configuration. A successful synthesis will return a URL to the streaming audio container of synthesized speech to the `TextToSpeech`'s `delegate`.
    /// - Note: The URL will be invalidated within 60 seconds of generation.
    /// - Parameter input: Parameters that specify the speech to synthesize.
    @objc public func synthesize(_ input: TextToSpeechInput) -> Void {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var request = URLRequest(url: URL(string: "https://core.pylon.com/speech/v1/tts/synthesize")!)
        request.addValue(self.configuration.authorization, forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        var inputFormat: String
        switch input.inputFormat {
        case .text:
            inputFormat = "text"
            break
        case .ssml:
            inputFormat = "ssml"
            break
        }
        let body = ["voice": input.voice,
                    inputFormat: input.input]
        request.httpBody =  try? JSONSerialization.data(withJSONObject: body, options: [])
        Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "request \(request.debugDescription) \(String(describing: request.allHTTPHeaderFields)) \(String(data: request.httpBody!, encoding: String.Encoding.ascii) ?? "no body")", delegate: self.delegate, caller: self)
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) -> Void in
            Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "task callback \(String(describing: response)) \(String(describing: String(data: data ?? Data(), encoding: String.Encoding.utf8)))) \(String(describing: error))", delegate: self.delegate, caller: self)

            DispatchQueue.main.async {
                if let error = error {
                    self.delegate?.failure(error: error)
                } else {
                    // unwrap the matryoshka doll that is the response body, responding with a failure if any layer is awry
                    guard let data = data else {
                        self.delegate?.failure(error: TextToSpeechErrors.deserialization("response body had no data"))
                        return
                    }
                    guard let dataObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                        self.delegate?.failure(error: TextToSpeechErrors.deserialization("could not deserialize response body"))
                        return
                    }
                    guard let body = dataObject as? [String: String] else {
                        self.delegate?.failure(error: TextToSpeechErrors.deserialization("deserialized response body was not a dictionary of strings"))
                        return
                    }
                    guard let urlString = body["url"] else {
                        self.delegate?.failure(error: TextToSpeechErrors.deserialization("deserialize response body dictionary did not contain the expected key"))
                        return
                    }
                    guard let url = URL(string: urlString) else {
                        self.delegate?.failure(error: TextToSpeechErrors.deserialization("could not generate a URL from the deserialize response body dictionary url key"))
                        return
                    }
                    // we have finally arrived at the single key-value pair in the response body
                    Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "response body url \(url)", delegate: self.delegate, caller: self)
                    
                    self.delegate?.success(url: url)
                }
            }
        }
        task.resume()
        Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "task \(task.state) \(task.progress) \(String(describing: task.response)) \(String(describing: task.error))", delegate: self.delegate, caller: self)
    }
}
