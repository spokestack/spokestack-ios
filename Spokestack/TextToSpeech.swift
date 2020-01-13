//
//  TextToSpeech.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 11/15/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CryptoKit
import Combine

private let TTSSpeechQueueName: String = "com.spokestack.ttsspeech.queue"
private let apiQueue = DispatchQueue(label: TTSSpeechQueueName, qos: .userInitiated, attributes: .concurrent)

/**
 This is the client entry point for the Spokestack Text to Speech (TTS) system. It provides the capability to synthesize textual input, and speak back the synthesis as audio system output. The synthesis and speech occur on asynchronous blocks so as to not block the client while it performs network and audio system activities.
 
 When inititalized, the TTS system communicates with the client either via a delegate that receive events, or via a publisher-subscriber pattern.
 
 ```
 // assume that self implements the TextToSpeechDelegate protocol.
 let configuration = SpeechConfiguration()
 let tts = TextToSpeech(self, configuration: configuration)
 let input = TextToSpeechInput()
 input.text = "Hello world!"
 tts.synthesize(input) // synthesize the provided default text input using the default synthetic voice and api key.
 tts.speak(input) // synthesize the same input as above, and play back the result using the default audio system.
 ```
 
 Using the TTS system requires setting an API client identifier (`SpeechConfiguration.apiId`) and API client secret (`SpeechConfiguration.apiSecret`) , which are used to cryptographically sign and meter TTS API usage.
 */
@available(iOS 13.0, *)
@objc public class TextToSpeech: NSObject {
    
    // MARK: Properties
    
    /// Delegate that receives TTS events.
    weak public var delegate: TextToSpeechDelegate?
    
    private var configuration: SpeechConfiguration
    private lazy var player: AVPlayer = AVPlayer()
    private var apiKey: SymmetricKey?
    private let ttsInputVoices = [0: "demo-male"]
    private let decoder = JSONDecoder()
    
    // MARK: Initializers

    /// Initializes a new text to speech instance without a delegate.
    /// - Note: An instance initialized this way is expected to use the pub/sub Combine interface, not the delegate interface, when calling `synthesize`.
    /// - Requires: `SpeechConfiguration.apiId` and `SpeechConfiguration.apiSecret`.
    /// - Parameter configuration: Speech configuration parameters.
    @objc public init(configuration: SpeechConfiguration) throws {
        self.configuration = configuration
        // create a symmetric key using the configured api secret key
        if let apiSecretEncoded = self.configuration.apiSecret.data(using: .utf8) {
            self.apiKey = SymmetricKey(data: apiSecretEncoded)
        } else {
            throw TextToSpeechErrors.apiKey("Unable to encode apiSecret.")
        }
        super.init()
    }
    
    /// Initializes a new text to speech instance.
    /// - Parameter delegate: Delegate that receives text to speech events.
    /// - Requires: `SpeechConfiguration.apiId` and `SpeechConfiguration.apiSecret`.
    /// - Parameter configuration: Speech configuration parameters.
    @objc public init(_ delegate: TextToSpeechDelegate, configuration: SpeechConfiguration) {
        self.delegate = delegate
        self.configuration = configuration
        // create a symmetric key using the configured api secret key
        if let apiSecretEncoded = self.configuration.apiSecret.data(using: .utf8) {
            self.apiKey = SymmetricKey(data: apiSecretEncoded)
        } else {
            self.delegate?.failure(error: TextToSpeechErrors.apiKey("Unable to encode apiSecret."))
        }
        super.init()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
    }
    
    // MARK: Public Functions
    
    /// Synthesize speech using the provided input parameters and speech configuration, and play back the result using the default audio system.
    ///
    /// Playback is provided as a convenience for the client. The client is responsible for coordinating the audio system resources and utilization required by `SpeechPipeline` and/or other media playback. The `TextToSpeechDelegate.didBeginSpeaking` and `TextToSpeechDelegate.didFinishSpeaking` callbacks may be utilized for this purpose.
    ///
    /// The `TextToSpeech` class handles all memory management for the playback components it utilizes.
    /// - Parameter input:  Parameters that specify the speech to synthesize.
    /// - Note: Playback will begin immediately after the synthesis results are received and sufficiently buffered.
    /// - Warning: `AVAudioSession.Category` and `AVAudioSession.CategoryOptions` must be set by the client to compatible settings that allow for playback through the desired audio sytem ouputs.
    @objc public func speak(_ input: TextToSpeechInput) -> Void {
        func play(result: TextToSpeechResult) {
            DispatchQueue.main.async {
                guard let url = result.url else {
                    self.delegate?.failure(error: TextToSpeechErrors.speak("Synthesis response is invalid."))
                    return
                }
                let playerItem = AVPlayerItem(url: url)
                NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(sender:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
                playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), options: [.new], context: nil)
                self.player.replaceCurrentItem(with: playerItem)
            }
        }
        self.synthesize(input: input, success: play)
    }
    
    /// Synthesize speech using the provided input parameters and speech configuration. A successful synthesis will return a URL to the streaming audio container of synthesized speech to the `TextToSpeech`'s `delegate`.
    /// - Note: The URL will be invalidated within 60 seconds of generation.
    /// - Parameter input: Parameters that specify the speech to synthesize.
    @objc public func synthesize(_ input: TextToSpeechInput) -> Void {
        self.synthesize(input: input, success: successHandler(result:))
    }
    
    // MARK: Public methods
    
    /// Synthesize speech using the provided list of inputs. A successful set of synthesises returns a list of synthesis results.
    /// - Parameter inputs: `Array` of `TextToSpeechInput`
    /// - Returns: `AnyPublisher<[TextToSpeechResult], Error>`
    public func synthesize(_ inputs: Array<TextToSpeechInput>) -> AnyPublisher<[TextToSpeechResult], Error> {
        
        // define an internal publishing function to accomplish the synthesis of a single tts input
        func synthesize(_ input: TextToSpeechInput) -> AnyPublisher<TextToSpeechResult, Error> {
            /// Since `createSynthesizeRequest` throws it can't be called directly without a publisher
            /// Using `Just` won't work because errors can't be returned.
            ///
            /// Using `Future`allows for the appropriate error to be returned
            let createSynthesizeRequestFuture = Future<URLRequest, Error> { promise in
                do {
                    let request = try self.createSynthesizeRequest(input)
                    promise(.success(request))
                } catch TextToSpeechErrors.apiKey(let message) {
                    promise(.failure(TextToSpeechErrors.apiKey(message)))
                } catch let error {
                    promise(.failure(error))
                }
            }.eraseToAnyPublisher()
            
            return
                createSynthesizeRequestFuture
                    .flatMap{urlRequst in
                        URLSession.shared
                            .dataTaskPublisher(for: urlRequst)
                            .receive(on: apiQueue)
                            .tryMap { data, response -> TextToSpeechResult in
                                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                                    throw TextToSpeechErrors.deserialization("response cannot be deserialized")
                                }
                                do {
                                    let result = try self.createSynthesizeResponse(data: data, response: httpResponse, inputFormat: input.inputFormat)
                                    return result
                                }
                        }
                }.eraseToAnyPublisher()
        }
        
        // map the list of tts inputs into the internal publishing function and merge the tts results into a list
        return Publishers.MergeMany(inputs.map(synthesize))
            .collect()
            .eraseToAnyPublisher()
    }
    

    // MARK: Private functions
    
    private func synthesize(input: TextToSpeechInput, success: ((TextToSpeechResult) -> Void)?) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var request: URLRequest
        do {
            request = try createSynthesizeRequest(input)
        } catch TextToSpeechErrors.apiKey(let message) {
            self.delegate?.failure(error: TextToSpeechErrors.apiKey(message))
            return
        } catch let error {
            self.delegate?.failure(error: error)
            return
        }
        
        Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "request \(request.debugDescription) \(String(describing: request.allHTTPHeaderFields)) \(String(data: request.httpBody!, encoding: String.Encoding.utf8) ?? "no body")", delegate: self.delegate, caller: self)
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) -> Void in
            Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "task callback \(String(describing: response)) \(String(describing: String(data: data ?? Data(), encoding: String.Encoding.utf8)))) \(String(describing: error))", delegate: self.delegate, caller: self)
            
            DispatchQueue.main.async {
                if let error = error {
                    self.delegate?.failure(error: error)
                } else {
                    // unwrap the matryoshka doll that is the response body, responding with a failure if any layer is awry
                    do {
                        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                            self.delegate?.failure(error: TextToSpeechErrors.deserialization("response cannot be deserialized"))
                            return
                        }
                        guard let d = data else {
                            self.delegate?.failure(error: TextToSpeechErrors.deserialization("response body has no data"))
                            return
                        }
                        let result = try self.createSynthesizeResponse(data: d, response: httpResponse, inputFormat: input.inputFormat)
                        success?(result)
                    } catch let error {
                        self.delegate?.failure(error: error)
                    }
                }
            }
        }
        task.resume()
    }
    
    private func successHandler(result: TextToSpeechResult) {
        self.delegate?.success(result: result)
    }
    
    // MARK: Internal functions
    
    internal func createSynthesizeRequest(_ input: TextToSpeechInput) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.spokestack.io/v1")!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(input.id, forHTTPHeaderField: "x-request-id")
        request.httpMethod = "POST"
        var body: [String:Any] = [:]
        switch input.inputFormat {
        case .ssml:
            body = [
                "query":"query iOSSynthesisSSML($voice: String!, $ssml: String!) {synthesizeSsml(voice: $voice, ssml: $ssml) {url}}",
                "variables":[
                    "voice":self.ttsInputVoices[input.voice.rawValue],
                    "ssml":input.input
                ]
            ]
            break
        case .text:
            body = [
                "query":"query iOSSynthesisText($voice: String!, $text: String!) {synthesizeText(voice: $voice, text: $text) {url}}",
                "variables":[
                    "voice":self.ttsInputVoices[input.voice.rawValue],
                    "text":input.input
                ]
            ]
            break
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.withoutEscapingSlashes])
        
        // create an authentication code for this request using the symmetric key
        guard let key = self.apiKey else {
            throw TextToSpeechErrors.apiKey("apiSecret is not configured.")
        }
        let code = HMAC<SHA256>.authenticationCode(for: request.httpBody!, using: key)
        // turn the code into a string, base64 encoded
        let codeEncoded = Data(code).base64EncodedString()
        // the request header must include the encoded code as "keyId"
        request.addValue("Spokestack \(self.configuration.apiId):\(codeEncoded)", forHTTPHeaderField: "Authorization")
        
        return request
    }
    
    internal func createSynthesizeResponse(data: Data, response: HTTPURLResponse, inputFormat: TTSInputFormat) throws -> TextToSpeechResult {
        // unwrap the matryoshka doll that is the response body, responding with a failure if any layer is awry
        guard let id = response.value(forHTTPHeaderField: "x-request-id") else {
            throw TextToSpeechErrors.deserialization("response headers did not contain request id")
        }
        switch inputFormat {
        case .ssml:
            let body = try self.decoder.decode(TTSSSMLResponseData.self, from: data)
            let result = TextToSpeechResult(id: id, url: body.data.synthesizeSsml.url)
            return result
        case .text:
            let body = try self.decoder.decode(TTSTextResponseData.self, from: data)
            let result = TextToSpeechResult(id: id, url: body.data.synthesizeText.url)
            return result
        }
    }
    
    /// Internal function that must be public for Objective-C compatibility reasons.
    /// - Warning: Client should never call this function.
    @available(*, deprecated, message: "Internal function that must be public for Objective-C compatibility reasons. Client should never call this function.")
    @objc
    func playerDidFinishPlaying(sender: Notification) {
        self.delegate?.didFinishSpeaking()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
    }
    
    /// Internal function that must be public for Objective-C compatibility reasons.
    /// - Warning: Client should never call this function.
    @available(*, deprecated, message: "Internal function that must be public for Objective-C compatibility reasons. Client should never call this function.")
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            switch keyPath {
            case #keyPath(AVPlayerItem.isPlaybackBufferEmpty):
                self.player.play()
                self.delegate?.didBeginSpeaking()
                break
            default:
                break
            }
        }
    }
}

// MARK: Internal data structures

fileprivate struct TTSSSMLResponseURL: Codable {
    let url: URL
}

fileprivate struct TTSSSMLResponseSynthesize: Codable {
    let synthesizeSsml: TTSSSMLResponseURL
}

fileprivate struct TTSSSMLResponseData: Codable {
    let data: TTSSSMLResponseSynthesize
}

fileprivate struct TTSTextResponseURL: Codable {
    let url: URL
}

fileprivate struct TTSTextResponseSynthesize: Codable {
    let synthesizeText: TTSTextResponseURL
}

fileprivate struct TTSTextResponseData: Codable {
    let data: TTSTextResponseSynthesize
}
