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
@objc public class SpokestackSpeechRecognizer: NSObject {

    /// Configuration for the recognizer.
    public var configuration: SpeechConfiguration
    /// Global state for the speech pipeline.
    public var context: SpeechContext

    private var task: URLSessionWebSocketTask?
    private var apiKey: SymmetricKey?
    private let decoder = JSONDecoder()
    private var isActive = false
    private var activation = 0
    private let emptyFrame = ([] as [Int]).withUnsafeBufferPointer {Data(buffer: $0)}
    private let initalizeStreamMessage: String

    /// Initializes an instance of SpokestackSpeechRecognizer.
    /// - Parameters:
    ///   - configuration: Configuration for the recognizer.
    ///   - context: Global state for the speech pipeline.
    @objc public init(_ configuration: SpeechConfiguration, context: SpeechContext) {
        self.configuration = configuration
        self.context = context
        if let apiSecretEncoded = self.configuration.apiSecret.data(using: .utf8) {
            self.apiKey = SymmetricKey(data: apiSecretEncoded)
            self.task = URLSession.shared.webSocketTask(with: URL(string: "wss://api.spokestack.io/v1/asr/websocket")!)
            
            // construct auth message
            /// - TODO: should use self.configuration.sampleRate, not hardcoded 16000hz
            let bodyDoubleEncoded = """
            "{\\"format\\": \\"PCM16LE\\", \\"rate\\": 16000, \\"language\\": \\"en\\", \\"limit\\": 10}"
            """
            let body = "{\"format\": \"PCM16LE\", \"rate\": 16000, \"language\": \"en\", \"limit\": 10}"
            let bodySigned = HMAC<SHA256>.authenticationCode(for: body.data(using: .utf8)!, using: self.apiKey!)
            let bodySignature = Data(bodySigned).base64EncodedString()
            self.initalizeStreamMessage = """
            {"keyId": "
            """ + self.configuration.apiId + """
            ", "signature": "
            """ + bodySignature + """
            ", "body":
            """ + " " + bodyDoubleEncoded + """
            }
            """
        } else {
            self.initalizeStreamMessage = ""
            self.context.error = SpeechPipelineError.apiKey("Unable to encode apiSecret.")
            self.context.dispatch(.error)
        }
        super.init()
    }

    private func activate() {
        self.startStream()
        self.isActive = true
    }

    private func deactivate() {
        // send an empty frame to trigger the asr into sending a final response
        self.stream(self.emptyFrame)
        //self.task?.suspend()
        self.context.isActive = false
        self.isActive = false
        self.activation = 0
        self.context.dispatch(.deactivate)
        //self.task?.cancel(with: .normalClosure, reason: nil)
    }
    
    private func startStream() {
        // send auth message
        self.task?.resume()
        self.task?.send(URLSessionWebSocketTask.Message.string(self.initalizeStreamMessage)) { error in
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
            })
        }
    }

    private func stream(_ frame: Data) {
        /// - TODO: implement a frame chunking policy to maximize MTU utilization. Should be able to chunk ~50ms of frame data at 16000khz. That's ~1500 bytes, but with TLS and websocket overhead the largest buffer without fragmentation is ~1400 bytes. It would probably make more sense to set the buffer size as a multiple of the audio frame size, so something like 1280 bytes.
        self.activation += self.configuration.frameWidth

        self.task?.send(URLSessionWebSocketTask.Message.data(frame)) { error in
            if let error = error {
                self.context.error = error
                self.context.dispatch(.error)
            }
        }
        self.task?.receive(completionHandler: self.receive)
    }
    
    private func receive(result: (Result<URLSessionWebSocketTask.Message, Error>)) {
        self.handle(result, handleResult: { r in
            if let hypothesis = r.hypotheses.last {
                self.context.confidence = hypothesis.confidence
                self.context.transcript = hypothesis.transcript
                if r.final {
                    self.context.dispatch(.recognize)
                }
            }
        })
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

extension SpokestackSpeechRecognizer: SpeechProcessor {
    
    /// Triggered by the speech pipeline, instructing the recognizer to begin streaming and processing audio.
    public func startStreaming() { }

    /// Triggered by the speech pipeline, instructing the recognizer to stop streaming audio and complete processing.
    public func stopStreaming() {
        if self.isActive {
            self.deactivate()
        }
    }
    
    /// Receives a frame of audio samples for processing. Interface between the `SpeechProcessor` and `AudioController` components.
    /// - Parameter frame: Frame of audio samples.
    public func process(_ frame: Data) {
        if self.context.isActive {
            if !self.isActive {
                self.activate()
                self.stream(frame)
            } else if
                (self.isActive
                    && self.activation <= self.configuration.wakeActiveMax)
                    ||
                    self.activation <= self.configuration.wakeActiveMin {
                self.stream(frame)
            } else {
                self.deactivate()
            }
        } else if self.isActive {
            self.deactivate()
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
