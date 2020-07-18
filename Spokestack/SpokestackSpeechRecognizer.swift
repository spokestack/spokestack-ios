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
    public var configuration: SpeechConfiguration
    
    public var context: SpeechContext
    
    private var task: URLSessionWebSocketTask?
    private var apiKey: SymmetricKey?
    private let decoder = JSONDecoder()

    
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
    
    public func startStreaming() {
        // setup
        guard let key = self.apiKey else {
            return
            //throw TextToSpeechErrors.apiKey("apiSecret is not configured.")
        }
        self.task = URLSession.shared.webSocketTask(with: URL(string: "wss://api.spokestack.io/v1/asr/websocket")!)
        
        // construct auth message
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
                self.configuration.delegateDispatchQueue.async {
                    self.context.listeners.forEach { listener in
                        listener.failure(speechError: error)
                    }
                }
            }
        }
        self.task?.receive() { result in
            self.handle(result, handleResult: { r in
                if r.status != "ok" {
                    self.configuration.delegateDispatchQueue.async {
                        self.context.listeners.forEach { listener in
                            listener.failure(speechError: SpeechPipelineError.illegalState("Spokestack ASR could not start because its status was \(r.status)."))
                        }
                    }
                }
            })
        }
    }
    
    public func stopStreaming() {
        self.context.isActive = false
        self.task?.cancel()
        self.configuration.delegateDispatchQueue.async {
            self.context.listeners.forEach({ listener in
                listener.didDeactivate()
            })
        }
    }
    
    public func process(_ frame: Data) {
        self.task?.send(URLSessionWebSocketTask.Message.data(frame)) { error in
            if let error = error {
                self.configuration.delegateDispatchQueue.async {
                    self.context.listeners.forEach { listener in
                        listener.failure(speechError: error)
                    }
                }
            }
        }
        self.task?.receive() { result in
            self.handle(result, handleResult: { r in
                if let hypothesis = r.hypotheses.last {
                    self.context.confidence = hypothesis.confidence
                    self.context.transcript = hypothesis.transcript
                    self.configuration.delegateDispatchQueue.async {
                        self.context.listeners.forEach({ listener in
                            listener.didRecognize(self.context)
                        })
                    }
                }
            })
        }
    }
    
    private func handle(_ result: Result<URLSessionWebSocketTask.Message, Error>, handleResult: (ASRResult) -> Void) {
        switch result {
        case .failure(let error):
            self.configuration.delegateDispatchQueue.async {
                self.context.listeners.forEach { listener in
                    listener.failure(speechError: error)
                }
            }
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
                    self.configuration.delegateDispatchQueue.async {
                        self.context.listeners.forEach { listener in
                            listener.failure(speechError: error)
                        }
                    }
                }
            case _:
                self.configuration.delegateDispatchQueue.async {
                    self.context.listeners.forEach { listener in
                        listener.failure(speechError: SpeechPipelineError.illegalState("Spokestack ASR response with something unknown: \(message)"))
                    }
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
