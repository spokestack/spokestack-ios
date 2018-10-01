//
//  GoogleSpeechRecognizer.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import googleapis

public class GoogleSpeechRecognizer: GoogleRecognizerConfiguration {
    
    // MARK: Public (properties)
    
    public static let sharedInstance: GoogleSpeechRecognizer = GoogleSpeechRecognizer()
    
    public var host: String = GoogleSpeechRecognizer.defaultHost
    
    public var apiKey: String = "REPLACE_ME"

    public var isStreaming: Bool {
        return self.streaming
    }
    
    // MARK: Private (properties)
    
    private static let defaultHost: String = "speech.googleapis.com"
    
    private var streaming: Bool = false
    
    private var audioData: NSMutableData = NSMutableData()
    
    private var client: Speech!
    
    private var writer: GRXBufferedPipe!
    
    private var call: GRPCProtoCall!
    
    lazy private var recognitionConfig: RecognitionConfig = {
        
        let config: RecognitionConfig = RecognitionConfig()
        
        config.encoding =  .linear16
        config.sampleRateHertz = Int32(AudioController.shared.sampleRate)
        config.languageCode = "en-US"
        config.maxAlternatives = 30
        config.enableWordTimeOffsets = true
        
        return config
    }()
    
    lazy private var streamingRecognitionConfig: StreamingRecognitionConfig = {
       
        let config: StreamingRecognitionConfig = StreamingRecognitionConfig()
        
        config.config = self.recognitionConfig
        config.singleUtterance = false
        config.interimResults = true
        
        return config
    }()
    
    lazy private var streamingRecognizerRequest: StreamingRecognizeRequest = {
       
        let recognizer: StreamingRecognizeRequest = StreamingRecognizeRequest()
        recognizer.streamingConfig = self.streamingRecognitionConfig
        
        return recognizer
    }()
    
    // MARK: Initializers
    
    public init() {
        AudioController.shared.delegate = self
    }
    
    // MARK: Public (methods)
    
    public func startStreaming() -> Void {
        
        if !self.streaming {
            AudioController.shared.startStreaming()
        }
    }
    
    public func stopStreaming() -> Void {
        
        if !self.streaming {
            return
        }
        
        self.writer.finishWithError(nil)
        self.streaming = false
        
        AudioController.shared.stopStreaming()
    }
    
    // MARK: Private (methods)
    
    private func analyzeAudioData(_ data: Data) -> Void {
        
        /// Convert to model and pass back to delegate
        
        
        /// if we aren't already streaming, set up a gRPC connection
        
        self.client = Speech(host: self.host)
        self.writer = GRXBufferedPipe()
        self.call = self.client.rpcToStreamingRecognize(withRequestsWriter: self.writer, eventHandler: {done, response, error in
            print("done \(done) response \(String(describing: response)) and error \(String(describing: error))")
            
            // TODO: Pass to private method
            //                    completion(response, error as? NSError)
        })
        
        /// authenticate using an API key obtained from the Google Cloud Console
        
        self.call.requestHeaders.setObject(NSString(string: self.apiKey),
                                           forKey:NSString(string:"X-Goog-Api-Key"))
        
        /// if the API key has a bundle ID restriction, specify the bundle ID like this
        
        self.call.requestHeaders.setObject(NSString(string:Bundle.main.bundleIdentifier!),
                                           forKey:NSString(string:"X-Ios-Bundle-Identifier"))
        
        self.call.start()
        self.streaming = true
        
        /// send an initial request message to configure the service
        
        self.writer.writeValue(self.streamingRecognizerRequest)
        
        /// send a request message containing the audio data
        
        let streamingRecognizeRequest: StreamingRecognizeRequest = StreamingRecognizeRequest()
        streamingRecognizeRequest.audioContent = audioData as Data
        
        self.writer.writeValue(streamingRecognizeRequest)
    }
}

extension GoogleSpeechRecognizer: AudioControllerDelegate {
    
    func setupFailed(_ error: String) {
        self.streaming = false
    }
    
    func processSampleData(_ data: Data) -> Void {

        /// Convert to model and pass back to delegate
        
        self.audioData.append(data)
        
        /// We recommend sending samples in 100ms chunks
        
        let chunkSize: Int = Int(0.1 * Double(AudioController.shared.sampleRate) * 2)
        
        if self.audioData.length > chunkSize {
            self.analyzeAudioData(data)
        }
    }
}
