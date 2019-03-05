//
//  SpeechContext.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 10/1/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

@objc public enum Event: Int {
    
    case activate, deactivate, recognize, error, trace
    
    public var description: String {
        
        switch self {
        case .activate:
            return "activate"
        case .deactivate:
            return "deactivate"
        case .recognize:
            return "recognize"
        case .error:
            return "error"
        case .trace:
            return "trace"
        }
    }
}

@objc public enum TraceLevel: Int {
    
    case debug = 10, perf = 20, info = 30, none = 100
    
    public var level: Int {
        
        switch self {
        case .debug:
            return TraceLevel.debug.rawValue
        case .perf:
            return TraceLevel.perf.rawValue
        case .info:
            return TraceLevel.info.rawValue
        case .none:
            return TraceLevel.none.rawValue
        }
    }
    
    public var description: String {
        
        switch self {
        case .debug:
            return "Debug \(TraceLevel.debug.rawValue)"
        case .perf:
            return "Performance \(TraceLevel.perf.rawValue)"
        case .info:
            return "Info \(TraceLevel.info.rawValue)"
        case .none:
            return "None \(TraceLevel.none.rawValue)"
        }
    }
}

@objc public class SpeechContext: NSObject {
    
    // MARK: Public (properties)
    
    @objc public var transcript: String = ""
    
    @objc public var confidence: Float = 0.0
    
    @objc public var isActive: Bool = false
    
    @objc public var isSpeech: Bool = false
    
    @objc public var buffer: Array<Data> = []
    
    @objc public var message: String = ""
    
    @objc public var traceLeve: Int = TraceLevel.none.rawValue
    
    @objc public var listeners: Array<SpeechEventDelegate> = []
    
    @objc public var error: Error!
    
    // MARK: Initializers
    
    override init() {
        super.init()
    }
    
    // MARK: Public (methods)
    
    @discardableResult
    public func attachBuffer(_ buffer: Array<Data>) -> SpeechContext {
        
        self.buffer = buffer
        return self
    }
    
    @discardableResult
    public func detachBuffer() -> SpeechContext {
        
        self.buffer.removeAll()
        return self
    }
    
    @discardableResult
    public func setSpeech(_ isSpeech: Bool) -> SpeechContext {
        
        self.isSpeech = isSpeech
        return self
    }
    
    @discardableResult
    public func setActive(_ isActive: Bool) -> SpeechContext {
        
        self.isActive = true
        return self
    }
    
    @discardableResult
    public func setTranscript(_ transcript: String) -> SpeechContext {
        
        self.transcript = transcript
        return self
    }
    
    @discardableResult
    public func setConfidence(_ confidence: Float) -> SpeechContext {
        
        self.confidence = confidence
        return self
    }
    
    @discardableResult
    public func setError(_ error: Error) -> SpeechContext {
        
        self.error = error
        return self
    }
    
    @discardableResult
    public func reset() -> SpeechContext {
        
        self.setSpeech(false)
        self.setActive(false)
        self.setTranscript("")
        self.setConfidence(0)
        self.message = ""
        
        return self
    }
    
    @discardableResult
    public func addListener(_ listener: SpeechEventDelegate) -> SpeechContext {
        
        self.listeners.append(listener)
        return self
    }
    
    @discardableResult
    public func removeListener<T: SpeechEventDelegate>(_ listener: T) -> SpeechContext where T: Equatable {
        
        self.listeners = self.listeners.filter {
            if let e = $0 as? T, e == listener {
                return false
            }
            return true
        }
        
        return self
    }
    
    @discardableResult
    public func dispatch(_ event: Event) -> SpeechContext {
        
        for listener in self.listeners {
            
            do {
                
                try listener.onEvent(event, context: self)
                
            } catch let error {
                
                if event != .trace {
                    self.traceInfo("dispatch-failed %s", params: error.localizedDescription)
                }
            }
        }
        
        return self
    }
}

extension SpeechContext {
    
    public func canTrace(_ level: TraceLevel) -> Bool {
        return level.rawValue >= self.traceLeve
    }
    
    @discardableResult
    public func traceDebug(_ format: String, params: Any...) -> SpeechContext {
        return self.trace(.debug, format: format, params: params)
    }
    
    @discardableResult
    public func traceInfo(_ format: String, params: Any...) -> SpeechContext {
        return self.trace(.info, format: format, params: params)
    }
    
    @discardableResult
    public func tracePerf(_ format: String, params: Any...) -> SpeechContext {
        return self.trace(.perf, format: format, params: params)
    }
    
    @discardableResult
    public func trace(_ level: TraceLevel, format: String, params: Any...) -> SpeechContext {
        
        if self.canTrace(level) {
            
            self.message = String(format: format, params)
            self.dispatch(.trace)
        }
        
        return self
    }
}
