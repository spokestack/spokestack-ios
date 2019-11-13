//
//  AudioController.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation

/// DispatchQueue for handling Spokestack audio processing
let audioProcessingQueue: DispatchQueue = DispatchQueue(label: "com.pylon.audio.callback")

/// Required callback function for AudioUnitSetProperty's AURenderCallbackStruct.
///
/// - SeeAlso: AURenderCallbackStruct
func recordingCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {

    guard let remoteIOUnit: AudioComponentInstance = AudioController.sharedInstance.remoteIOUnit else {
        return kAudioServicesSystemSoundUnspecifiedError
    }
    var status: OSStatus = noErr
    let channelCount: UInt32 = 1
    var bufferList = AudioBufferList()
    bufferList.mNumberBuffers = channelCount
    let buffers = UnsafeMutableBufferPointer<AudioBuffer>(start: &bufferList.mBuffers,
                                                          count: Int(bufferList.mNumberBuffers))
    buffers[0].mNumberChannels = 1
    buffers[0].mDataByteSize = inNumberFrames * 2
    buffers[0].mData = nil
    
    /// get the recorded samples
    
    status = AudioUnitRender(remoteIOUnit,
                             ioActionFlags,
                             inTimeStamp,
                             inBusNumber,
                             inNumberFrames,
                             UnsafeMutablePointer<AudioBufferList>(&bufferList))
    if status != noErr {
        return status
    }
        
    if buffers[0].mData != nil {
        let data: Data = Data(bytes: buffers[0].mData!, count: Int(buffers[0].mDataByteSize))
        audioProcessingQueue.sync {
            AudioController.sharedInstance.delegate?.process(data)
        }
    }
    
    return noErr
}

/// Singleton class for configuring and controlling a stream of audio frames.
class AudioController {
    
    // MARK: Public (properties)
    
    /// Singleton instance
    public static let sharedInstance: AudioController = AudioController()
    /// Delegate for receivng the `recordingCallback`'s `process` function.
    /// - SeeAlso: recordingCallback
    public weak var delegate: AudioControllerDelegate?
    /// Delegate for receiving `setupFailure` events in the speech pipeline.
    public weak var pipelineDelegate: PipelineDelegate?
    /// Configuration for the audio controller.
    public var configuration: SpeechConfiguration = SpeechConfiguration()

    // MARK: Private (properties)
    
    // private var bufferDuration: TimeInterval = TimeInterval((configuration.sampleRate / 1000) * configuration.frameWidth)
    fileprivate var remoteIOUnit: AudioComponentInstance?
    lazy private var audioComponentDescription: AudioComponentDescription = {
        var componentDescription: AudioComponentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Output
        componentDescription.componentSubType = kAudioUnitSubType_RemoteIO
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        return componentDescription
    }()
    
    // MARK: Initializers
    
    deinit {
        if let riou = remoteIOUnit {
            AudioComponentInstanceDispose(riou)
        }
        if let ioUnit: AudioComponentInstance = self.remoteIOUnit {
            AudioComponentInstanceDispose(ioUnit)
        }
    }
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteChanged),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    // MARK: Public functions
    
    /// Begin sending audio frames to the AudioControllerDelegate.
    /// - SeeAlso: AudioControllerDelegate
    /// - Parameter context: Global state for the speech pipeline.
    func startStreaming(context: SpeechContext) -> Void {
        self.checkAudioSession()
        do {
            try self.start()
        } catch AudioError.audioSessionSetup(let message) {
            self.pipelineDelegate?.setupFailed(message)
        } catch {
            self.pipelineDelegate?.setupFailed("An unknown error occured starting the stream")
        }
    }
    
    /// Stop sending audio frames to the AudioControllerDelegate.
    /// - SeeAlso: AudioControllerDelegate
    /// - Parameter context: Global state for the speech pipeline.
    func stopStreaming(context: SpeechContext) -> Void {
        do {
            try self.stop()
        } catch AudioError.audioSessionSetup(let message) {
            self.pipelineDelegate?.setupFailed(message)
        } catch {
            self.pipelineDelegate?.setupFailed("An unknown error occured ending the stream")
        }
    }
    
    // MARK: Private functions
    
    @discardableResult
    private func start() throws -> OSStatus {
        var status: OSStatus = noErr
        status = self.prepareRemoteIOUnit()
        if status != noErr {
            throw AudioError.audioSessionSetup("prepareRemoteIOUnit returned " + status.description)
        }
        if let riou = remoteIOUnit {
            status = AudioOutputUnitStart(riou)
        }
        if status != noErr {
            throw AudioError.audioSessionSetup("AudioOutputUnitStart returned " + status.description)
        }
        return status
    }
    
    @discardableResult
    private func stop() throws -> OSStatus {
        var status: OSStatus = noErr
        if let riou = remoteIOUnit {
            status = AudioOutputUnitStop(riou)
        }
        if status != noErr {
            throw AudioError.audioSessionSetup("AudioOutputUnitStop returned " + status.description)
        }
        return status
    }
    
    private func checkAudioSession() {
        switch AVAudioSession.sharedInstance().category {
        case AVAudioSession.Category.record:
            break
        case AVAudioSession.Category.playAndRecord:
            break
        default:
            self.pipelineDelegate?.setupFailed("Incompatible AudioSession category is set.")
        }
    }
    
    private func prepareRemoteIOUnit() -> OSStatus {
        var status: OSStatus = noErr
        let remoteIOComponent = AudioComponentFindNext(nil, &audioComponentDescription)
        status = AudioComponentInstanceNew(remoteIOComponent!, &remoteIOUnit)
        if status != noErr {
            return status
        }
        
        // MARK: Configure the RemoteIO unit for input
        
        let bus1: AudioUnitElement = 1
        var oneFlag: UInt32 = 1
        status = AudioUnitSetProperty(self.remoteIOUnit!,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      bus1,
                                      &oneFlag,
                                      UInt32(MemoryLayout<UInt32>.size));
        if status != noErr {
            return status
        }
        
        // MARK: set format for mic input (bus 1) on RemoteIO unit's output scope
        var asbd: AudioStreamBasicDescription = AudioStreamBasicDescription()
        asbd.mSampleRate = Double(self.configuration.sampleRate)
        asbd.mFormatID = kAudioFormatLinearPCM
        asbd.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        asbd.mBytesPerPacket = 2
        asbd.mFramesPerPacket = 1
        asbd.mBytesPerFrame = 2
        asbd.mChannelsPerFrame = 1
        asbd.mBitsPerChannel = 16
        status = AudioUnitSetProperty(self.remoteIOUnit!,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      bus1,
                                      &asbd,
                                      UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        if (status != noErr) {
            return status
        }
        
        // MARK: Set the recording callback
        
        var callbackStruct: AURenderCallbackStruct = AURenderCallbackStruct()
        callbackStruct.inputProc = recordingCallback
        callbackStruct.inputProcRefCon = nil
        status = AudioUnitSetProperty(self.remoteIOUnit!,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      bus1,
                                      &callbackStruct,
                                      UInt32(MemoryLayout<AURenderCallbackStruct>.size));
        if status != noErr {
            return status
        }
        
        // MARK: Initialize the RemoteIO unit
        
        return AudioUnitInitialize(self.remoteIOUnit!)
    }
    
    private func debug() {
        let session = AVAudioSession.sharedInstance()
        let sss: String = session.category.rawValue
        let sco: String = session.categoryOptions.rawValue.description
        let sioap: String = session.isOtherAudioPlaying.description
        Trace.trace(Trace.Level.DEBUG, configLevel: configuration.tracing, message: "current category: \(sss) +  options: \(sco) isOtherAudioPlaying: \(sioap) bufferduration  \(session.ioBufferDuration.description)", delegate: self.pipelineDelegate, caller: self)
        let route_inputs: String = session.currentRoute.inputs.debugDescription
        let route_outputs: String = session.currentRoute.outputs.debugDescription
        let preferredInput: String = session.preferredInput.debugDescription
        let usb_outputs: String = session.outputDataSources?.debugDescription ?? "none"
        let inputs: String = session.availableInputs?.debugDescription ?? "none"
        Trace.trace(Trace.Level.DEBUG, configLevel: configuration.tracing, message: "inputs: \(inputs) preferredinput: \(preferredInput) input: \(route_inputs) output: \(route_outputs) usb_outputs: \(usb_outputs)", delegate: self.pipelineDelegate, caller: self)
    }
    
    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        Trace.trace(Trace.Level.DEBUG, configLevel: configuration.tracing, message: "audioRouteChanged reason: \(reasonValue.description) notification: \(userInfo.debugDescription)", delegate: self.pipelineDelegate, caller: self)
        debug()
        let session = AVAudioSession.sharedInstance()
        switch reason {
        case .newDeviceAvailable:
            Trace.trace(Trace.Level.DEBUG, configLevel: configuration.tracing, message: "AudioController audioRouteChanged new output:  \(session.currentRoute.outputs.description)", delegate: self.pipelineDelegate, caller: self)
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                Trace.trace(Trace.Level.DEBUG, configLevel: configuration.tracing, message: "AudioController audioRouteChanged old output: \(previousRoute.outputs.description)", delegate: self.pipelineDelegate, caller: self)
            }
        case .categoryChange:
            Trace.trace(Trace.Level.DEBUG, configLevel: configuration.tracing, message: "AudioController audioRouteChanged new category: \(session.category.rawValue)", delegate: self.pipelineDelegate, caller: self)
        default: ()
        }
    }
}
