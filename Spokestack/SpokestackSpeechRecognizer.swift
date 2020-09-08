//
//  SpokestackSpeechRecognizer.swift
//  Spokestack
//
//  Created by Noel Weichbrodt on 7/16/20.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import CryptoKit

@available(iOS 13.0, *)
@objc public class SpokestackSpeechRecognizer: NSObject, SpeechProcessor {
    
    /// Configuration for the recognizer.
    public var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    public var context: SpeechContext
    
    private var task: URLSessionWebSocketTask?
    private var apiKey: SymmetricKey?
    private let decoder = JSONDecoder()
    private var active = false
    private var activation = 0
    private let emptyFrame = ([] as [Int]).withUnsafeBufferPointer {Data(buffer: $0)}
    
    /// Initializes an instance of SpokestackSpeechRecognizer.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        if let apiSecretEncoded = self.configuration.apiSecret.data(using: .utf8) {
            self.apiKey = SymmetricKey(data: apiSecretEncoded)
        } else {
            //throw TextToSpeechErrors.apiKey("Unable to encode apiSecret.")
        }
        super.init()
    }
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    public func startStreaming() {
        // setup
        guard let key = self.apiKey else {
            return
            //throw TextToSpeechErrors.apiKey("apiSecret is not configured.")
        }
        self.task = URLSession.shared.webSocketTask(with: URL(string: "wss://api.spokestack.io/v1/asr/websocket")!)
        
        // construct auth message
        /// - TODO: should use self.configuration.sampleRate, not hardcoded 16000hz
        let bodyDoubleEncoded = """
"{\\"format\\": \\"PCM16LE\\", \\"rate\\": 16000, \\"language\\": \\"en\\", \\"limit\\": 10}"
"""
        let body = "{\"format\": \"PCM16LE\", \"rate\": 16000, \"language\": \"en\", \"limit\": 10}"
        let bodySigned = HMAC<SHA256>.authenticationCode(for: body.data(using: .utf8)!, using: key)
        let bodySignature = Data(bodySigned).base64EncodedString()
        let message = """
{"keyId": "
""" + self.configuration.apiId + """
", "signature": "
""" + bodySignature + """
", "body":
""" + " " + bodyDoubleEncoded + """
}
"""
        
        // send auth message
        self.task?.resume()
        self.task?.send(URLSessionWebSocketTask.Message.string(message)) { error in
            if let error = error {
                self.context.error = error
                self.context.dispatch(.error)
            }
        }
        self.task?.receive() { result in
            self.handle(result, handleResult: { r in
                if r.status != "ok" {
                    self.context.error = SpeechPipelineError.illegalState("Spokestack ASR could not start because its status was \(r.status).")
                    self.context.dispatch(.error)
                }
                self.activate()
            })
        }
    }

    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    public func stopStreaming() {
        self.deactivate()
        self.task?.cancel()
        self.context.dispatch(.deactivate)
    }

    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    /// - Parameter frame: Frame of audio samples.
    public func process(_ frame: Data) {
        if (self.active && self.context.isActive && self.activation < self.configuration.wakeActiveMax) || (self.active && self.activation < self.configuration.wakeActiveMin) {
            self.stream(frame)
        } else if (self.active && !self.context.isActive && self.activation >= self.configuration.wakeActiveMin) || (self.active && self.activation >= self.configuration.wakeActiveMax) {
            self.deactivate()
        } else if !self.active && self.context.isActive {
            self.activate()
            self.stream(frame)
        }
    }

    private func activate() {
        self.activation = 0
        self.active = true
    }

    private func deactivate() {
        self.context.isActive = false
        self.active = false
        self.activation = 0
        // send an empty frame to trigger the asr into sending a final response
        self.stream(self.emptyFrame)
    }

    private func stream(_ frame: Data) {
        /// - TODO: implement a frame chunking policy to maximize MTU utilization. Should be able to chunk ~50ms of frame data at 16000khz (~1500 bytes).
        self.activation += self.configuration.frameWidth

        self.task?.send(URLSessionWebSocketTask.Message.data(frame)) { error in
            if let error = error {
                self.context.error = error
                self.context.dispatch(.error)
            }
        }
        self.task?.receive() { result in
            self.handle(result, handleResult: { r in
                if let hypothesis = r.hypotheses.last {
                    self.context.confidence = hypothesis.confidence
                    self.context.transcript = hypothesis.transcript
                    self.context.dispatch(.recognize)
                }
            })
        }
    }

    private func handle(_ result: Result<URLSessionWebSocketTask.Message, Error>, handleResult: (ASRResult) -> Void) {
        switch result {
        case .failure(let error):
            self.context.error = error
            self.context.dispatch(.error)
        case .success(let message):
            switch message {
            case .string(let json):
                do {
                    guard let jsonData = json.data(using: .utf8) else {
                        throw SpeechPipelineError.invalidResponse("Could not desearialize the ASR response.")
                    }
                    let r = try self.decoder.decode(ASRResult.self, from: jsonData)
                    if let error = r.error {
                        throw SpeechPipelineError.failure("Spokestack ASR responded with an error: \(error)")
                    } else {
                        handleResult(r)
                    }
                } catch let error {
                    self.context.error = error
                    self.context.dispatch(.error)
                }
            case _:
                self.configuration.delegateDispatchQueue.async {
                    self.context.error = SpeechPipelineError.illegalState("Spokestack ASR response with something unknown: \(message)")
                    self.context.dispatch(.error)
                }
            }
        }
    }
}

fileprivate struct ASRHypotheses: Codable {
    let confidence: Float
    let transcript: String
}

fileprivate struct ASRResult: Codable {
    let error: String?
    let final: Bool
    let status: String
    let hypotheses: [ASRHypotheses]
}
