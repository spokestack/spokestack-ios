//
//  TextToSpeech.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 11/15/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import CryptoKit
import Combine

private let TTSQueueName: String = "io.spokestack.tts.queue"
private let apiQueue = DispatchQueue(label: TTSQueueName, qos: .userInitiated, attributes: .concurrent)

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
    public var delegates: [SpokestackDelegate] = []
    
    private var configuration: SpeechConfiguration
    private lazy var player: AVPlayer = AVPlayer()
    private var apiKey: SymmetricKey?
    private let decoder = JSONDecoder()
    
    // MARK: Initializers

    /// Initializes a new text to speech instance without a delegate.
    /// - Warning: An instance initialized this way is expected to use the pub/sub `Combine` interface, not the delegate interface, when calling `synthesize`.
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
    @objc public init(_ delegates: [SpokestackDelegate], configuration: SpeechConfiguration) {
        self.delegates = delegates
        self.configuration = configuration
        // create a symmetric key using the configured api secret key
        if let apiSecretEncoded = self.configuration.apiSecret.data(using: .utf8) {
            self.apiKey = SymmetricKey(data: apiSecretEncoded)
        } else {
            self.configuration.delegateDispatchQueue.async {
                delegates.forEach { $0.failure(error: TextToSpeechErrors.apiKey("Unable to encode apiSecret.")) }
            }
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
            DispatchQueue.global(qos: .userInitiated).async {
                guard let url = result.url else {
                    self.dispatch { $0.failure(error: TextToSpeechErrors.speak("Synthesis response is invalid.")) }
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
    
    /// Stops playback of the current synthesis result.
    @objc public func stopSpeaking() -> Void {
        self.player.pause()
        self.finishPlayback()
    }
    
    /// Synthesize speech using the provided input parameters and speech configuration. A successful synthesis will return a URL to the streaming audio container of synthesized speech to the `TextToSpeech`'s `delegate`.
    /// - Note: The URL will be invalidated within 60 seconds of generation.
    /// - Parameter input: Parameters that specify the speech to synthesize.
    @objc public func synthesize(_ input: TextToSpeechInput) -> Void {
        self.synthesize(input: input, success: successHandler)
    }

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
                                guard let httpResponse = response as? HTTPURLResponse else {
                                    throw TextToSpeechErrors.deserialization("Response is not a valid HTTPURLResponse")
                                }
                                if httpResponse.statusCode != 200 {
                                    throw TextToSpeechErrors.httpStatusCode("The HTTP status was \(httpResponse.statusCode); cannot process response.")
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
    
    private func dispatch(_ handler: @escaping (SpokestackDelegate) -> Void) {
        self.configuration.delegateDispatchQueue.async {
            self.delegates.forEach(handler)
        }
    }
    
    private func synthesize(input: TextToSpeechInput, success: ((TextToSpeechResult) -> Void)?) {
        let session = URLSession(configuration: URLSessionConfiguration.default)
        var request: URLRequest
        do {
            request = try createSynthesizeRequest(input)
        } catch TextToSpeechErrors.apiKey(let message) {
            self.dispatch { $0.failure(error: TextToSpeechErrors.apiKey(message)) }
            return
        } catch let error {
            self.dispatch { $0.failure(error: error) }
            return
        }
        
        Trace.trace(Trace.Level.DEBUG, message: "request \(request.debugDescription) \(String(describing: request.allHTTPHeaderFields)) \(String(data: request.httpBody!, encoding: String.Encoding.utf8) ?? "no body")", config: self.configuration, delegates: self.delegates, caller: self)
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) -> Void in
            Trace.trace(Trace.Level.DEBUG, message: "task callback \n response: \(String(describing: response)) \n response data: \(String(describing: String(data: data ?? Data(), encoding: String.Encoding.utf8)))) \n response error: \(String(describing: error))", config: self.configuration, delegates: self.delegates, caller: self)
            
            DispatchQueue.global(qos: .userInitiated).async {
                if let error = error {
                    self.dispatch { $0.failure(error: error) }
                } else {
                    // unwrap the matryoshka doll that is the response body, responding with a failure if any layer is awry
                    do {
                        guard let httpResponse = response as? HTTPURLResponse else {
                            self.dispatch { $0.failure(error:   TextToSpeechErrors.deserialization("Response is not a valid HTTPURLResponse")) }
                            return
                        }
                        if httpResponse.statusCode != 200 {
                            self.dispatch { $0.failure(error:  TextToSpeechErrors.httpStatusCode("The HTTP status was \(httpResponse.statusCode); cannot process response.")) }
                            return
                        }
                        guard let d = data else {
                            self.dispatch { $0.failure(error:  TextToSpeechErrors.deserialization("response body has no data")) }
                            return
                        }
                        let result = try self.createSynthesizeResponse(data: d, response: httpResponse, inputFormat: input.inputFormat)
                        success?(result)
                    } catch let error {
                        self.dispatch { $0.failure(error: error) }
                    }
                }
            }
        }
        task.resume()
    }
    
    private func successHandler(result: TextToSpeechResult) {
        self.dispatch { $0.success?(result: result) }
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
                    "voice": input.voice,
                    "ssml": input.input
                ]
            ]
            break
        case .markdown:
            body = [
                "query":"query iOSSynthesisMarkdown($voice: String!, $markdown: String!) {synthesizeMarkdown(voice: $voice, markdown: $markdown) {url}}",
                "variables":[
                    "voice": input.voice,
                    "markdown": input.input
                ]
            ]
            break
        case .text:
            body = [
                "query":"query iOSSynthesisText($voice: String!, $text: String!) {synthesizeText(voice: $voice, text: $text) {url}}",
                "variables":[
                    "voice": input.voice,
                    "text": input.input
                ]
            ]
            break
        default:
            // necessary case due to objc interop with enum
            throw TextToSpeechErrors.format("The input format must be specified.")
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
        // NB the XCode debugger locals won't show a hydrated `body` for some reason. If you're here, you may intepret that as a bug. Instead, `po body.data` or use a debug print in the caller's code to force evaluation of the actually hydrated object.
        let body = try self.decoder.decode(TTSTResponse.self, from: data)
        if let e = body.errors {
            let message = e.map { $0.message }.joined(separator: " ")
            throw TextToSpeechErrors.format(message)
        }
        guard let data = body.data else
        {
            throw TextToSpeechErrors.deserialization("Could not deserialize the response.")
        }
        var url: URL { switch inputFormat {
        // NB the inputFormat switch guarantees safe access to the synthesisFormat url.
        case .ssml: return data.synthesizeSsml!.url
        case .markdown: return data.synthesizeMarkdown!.url
        case .text: return data.synthesizeText!.url
        }}
        let result = TextToSpeechResult(id: id, url: url)
        return result
    }
    
    /// Internal function that must be public for Objective-C compatibility reasons.
    /// - Warning: Client should never call this function.
    @available(*, deprecated, message: "Internal function that must be public for Objective-C compatibility reasons. Client should never call this function.")
    @objc
    func playerDidFinishPlaying(sender: Notification) {
        self.finishPlayback()
    }
    
    private func finishPlayback() {
        self.dispatch { $0.didFinishSpeaking?() }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
    }
    
    /// Internal function that must be public for Objective-C compatibility reasons.
    /// - Warning: Client should never call this function.
    @available(*, deprecated, message: "Internal function that must be public for Objective-C compatibility reasons. Client should never call this function.")
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.global(qos: .userInitiated).async {
            switch keyPath {
            case #keyPath(AVPlayerItem.isPlaybackBufferEmpty):
                self.player.play()
                self.dispatch { $0.didBeginSpeaking?() }
                break
            default:
                break
            }
        }
    }
}

// MARK: Internal data structures

fileprivate struct TTSResponseErrorLocation: Codable {
    let column: Int
    let line: Int
}

fileprivate struct TTSResponseError: Codable {
    let locations: [TTSResponseErrorLocation]
    let message: String
}

fileprivate struct TTSResponseURL: Codable {
    let url: URL
}

fileprivate struct TTSResponseSynthesize: Codable {
    let synthesizeText: TTSResponseURL?
    let synthesizeMarkdown: TTSResponseURL?
    let synthesizeSsml: TTSResponseURL?
}

fileprivate struct TTSTResponse: Codable {
    let data: TTSResponseSynthesize?
    let errors: [TTSResponseError]?
}
