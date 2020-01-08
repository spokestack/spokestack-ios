//
//  TextToSpeechQueue.swift
//  Spokestack
//
//  Created by Cory Wiles on 12/15/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import Combine

private let TTSSpeechQueueName: String = "com.spokestack.ttsspeech.queue"

private let apiQueue = DispatchQueue(label: TTSSpeechQueueName, qos: .userInitiated, attributes: .concurrent)

public struct TTSQueueURL: Codable {
    
    public let url: String
}

@available(iOS 13.0, *)
@objc public class TextToSpeechQueue: NSObject {
    
    // MARK: Properties
    
    private var configuration: SpeechConfiguration
    
    private let decoder = JSONDecoder()
    
    private let ttsInputVoices = [0: "demo-male"]
    
    // MARK: Initializers
    
    @objc public init(_ configuration: SpeechConfiguration) {
        self.configuration = configuration
        super.init()
    }
    
    @objc public override init() {
        self.configuration = SpeechConfiguration()
        super.init()
    }
    
    // MARK: Public methods
    
    public func synthesize(_ inputs: Array<TextToSpeechInput>) -> AnyPublisher<[TextToSpeechResult], Error> {

        return self.mergedInputs(inputs).scan([]) { inputs, input -> [TextToSpeechResult] in
            return inputs + [input]
        }
        .eraseToAnyPublisher()
    }
    
    public func synthesize(_ input: TextToSpeechInput) -> AnyPublisher<TextToSpeechResult, Error> {
        
        var request = URLRequest(url: URL(string: "https://api.spokestack.io/v1")!)
        request.addValue(input.id, forHTTPHeaderField: "x-request-id")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"

        let body: Dictionary<String, Any> = [
            "query":"query iOSSynthesisText($voice: String!, $text: String!) {synthesizeText(voice: $voice, text: $text) {url}}",
            "variables": [
                "voice": self.ttsInputVoices[input.voice.rawValue],
                "text": input.input
            ]
        ]
        
        request.httpBody =  try? JSONSerialization.data(withJSONObject: body, options: [])
        
        return URLSession.shared
            .dataTaskPublisher(for: request)
            .handleEvents(receiveSubscription: { _ in
              print("Network request will start")
            }, receiveOutput: { output in
                print("Network request data received \(output.response)")
            }, receiveCancel: {
              print("Network request cancelled")
            })
            .receive(on: apiQueue)
            .tryMap { data, response -> TextToSpeechResult in
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    throw TextToSpeechErrors.deserialization("response cannot be deserialized")
                }

                guard let id = httpResponse.value(forHTTPHeaderField: "x-request-id") else {
                    throw TextToSpeechErrors.deserialization("response headers did not contain request id")
                }
                
                let body = try self.decoder.decode(TTSTextResponseData.self, from: data)
                let result: TextToSpeechResult = TextToSpeechResult(id: id, url: body.data.synthesizeText.url)
                
                return result
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: Private methods)
    
    private func mergedInputs(_ inputs: Array<TextToSpeechInput>) -> AnyPublisher<TextToSpeechResult, Error> {
        
        precondition(!inputs.isEmpty)
        
        let initialPublisher = self.synthesize(inputs[0])
        let remainder = Array(inputs.dropFirst())
        
        return remainder.reduce(initialPublisher) { combined, ttsInput in
            return combined
                .merge(with: synthesize(ttsInput))
                .eraseToAnyPublisher()
        }
    }
}
