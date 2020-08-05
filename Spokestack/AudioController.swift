//
//  AudioController.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation
import AVFoundation
import Dispatch

/// DispatchQueue for handling Spokestack audio processing
internal let audioProcessingQueue: DispatchQueue = DispatchQueue(label: "io.spokestack.audiocontroller", qos: .userInteractive)

/// Required callback function for AudioUnitSetProperty's AURenderCallbackStruct. Sends frames of audio to the `stageInstances` in `SpeechContext`.
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
    let bufferSize = inNumberFrames * 2
    var bufferList = AudioBufferList()
    bufferList.mNumberBuffers = channelCount
    bufferList.mBuffers.mNumberChannels = 1
    bufferList.mBuffers.mDataByteSize = bufferSize
    bufferList.mBuffers.mData = nil
    
    return withUnsafeMutablePointer(to: &bufferList) { (buffers) -> OSStatus in
        // render the recorded samples into the AudioBuffers
        status = AudioUnitRender(remoteIOUnit,
                                 ioActionFlags,
                                 inTimeStamp,
                                 inBusNumber,
                                 inNumberFrames,
                                 buffers)
        // verify that the rendering did not error
        if status != noErr {
            return status
        }
        // convert the samples into Data and send to the stages
        if let samples = buffers.pointee.mBuffers.mData {
            let data: Data = Data(bytes: samples, count: Int(bufferSize))
            // NB: errors like
            // AUBuffer.h:61:GetBufferList: EXCEPTION (-1) [mPtrState == kPtrsInvalid is false]: ""
            // are irrelevant
            audioProcessingQueue.sync {
                AudioController.sharedInstance.context?.stageInstances.forEach { stage in
                    stage.process(data)
                }
            }
        }
        return noErr
    }
}

/// Singleton class for configuring and controlling a stream of audio frames.
class AudioController {
    
    // MARK: Public (properties)
    
    /// Singleton instance
    public static let sharedInstance: AudioController = AudioController()
    /// Configuration for the audio controller.
    public var configuration: SpeechConfiguration?
    public var context: SpeechContext?
    
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
    func startStreaming() -> Void {
        self.checkAudioSession()
        do {
            try self.start()
        } catch AudioError.audioSessionSetup(let message) {
            self.configuration?.delegateDispatchQueue.async {
                self.context?.listeners.forEach({ listener in
                    listener.failure(speechError: AudioError.audioController(message))
                })
            }
        } catch {
            self.configuration?.delegateDispatchQueue.async {
                self.context?.listeners.forEach({ listener in
                    listener.failure(speechError: AudioError.audioController("An unknown error occured starting the stream"))
                })
            }
        }
    }
    
    /// Stop sending audio frames to the AudioControllerDelegate.
    /// - SeeAlso: AudioControllerDelegate
    func stopStreaming() -> Void {
        do {
            try self.stop()
        } catch AudioError.audioSessionSetup(let message) {
            self.configuration?.delegateDispatchQueue.async {
                self.context?.listeners.forEach({ listener in
                    listener.failure(speechError: AudioError.audioController(message))
                })
            }
        } catch {
            self.configuration?.delegateDispatchQueue.async {
                self.context?.listeners.forEach({ listener in
                    listener.failure(speechError: AudioError.audioController("An unknown error occured ending the stream"))
                })
            }
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
            self.configuration?.delegateDispatchQueue.async {
                self.context?.listeners.forEach({ listener in
                    listener.failure(speechError: AudioError.audioSessionSetup("Incompatible AudioSession category is set."))
                })
            }
        }
    }
    
    private func prepareRemoteIOUnit() -> OSStatus {
        var status: OSStatus = noErr
        guard let config = self.configuration else { return OSStatus(-1) } // TODO: value for OSStatus?
        let remoteIOComponent = AudioComponentFindNext(nil, &audioComponentDescription)
        status = AudioComponentInstanceNew(remoteIOComponent!, &remoteIOUnit)
        if status != noErr {
            return status
        }
        
        // Configure the RemoteIO unit for input
        
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
        
        // set format for mic input (bus 1) on RemoteIO unit's output scope
        var asbd: AudioStreamBasicDescription = AudioStreamBasicDescription()
        asbd.mSampleRate = Double(config.sampleRate)
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
                
        return AudioUnitInitialize(self.remoteIOUnit!)
    }
    
    private func debug() {
        let session = AVAudioSession.sharedInstance()
        let sss: String = session.category.rawValue
        let sco: String = session.categoryOptions.rawValue.description
        let sioap: String = session.isOtherAudioPlaying.description
        Trace.trace(Trace.Level.DEBUG, message: "current category: \(sss) +  options: \(sco) isOtherAudioPlaying: \(sioap) bufferduration  \(session.ioBufferDuration.description)", config: self.configuration, context: self.context, caller: self)
        let route_inputs: String = session.currentRoute.inputs.debugDescription
        let route_outputs: String = session.currentRoute.outputs.debugDescription
        let preferredInput: String = session.preferredInput.debugDescription
        let usb_outputs: String = session.outputDataSources?.debugDescription ?? "none"
        let inputs: String = session.availableInputs?.debugDescription ?? "none"
        Trace.trace(Trace.Level.DEBUG, message: "inputs: \(inputs) preferredinput: \(preferredInput) input: \(route_inputs) output: \(route_outputs) usb_outputs: \(usb_outputs)", config: self.configuration, context: self.context, caller: self)
    }
    
    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        Trace.trace(Trace.Level.DEBUG, message: "audioRouteChanged reason: \(reasonValue.description) notification: \(userInfo.debugDescription)", config: self.configuration, context: self.context, caller: self)
        debug()
        let session = AVAudioSession.sharedInstance()
        switch reason {
        case .newDeviceAvailable:
            Trace.trace(Trace.Level.DEBUG, message: "AudioController audioRouteChanged new output:  \(session.currentRoute.outputs.description)", config: self.configuration, context: self.context, caller: self)
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                Trace.trace(Trace.Level.DEBUG, message: "AudioController audioRouteChanged old output: \(previousRoute.outputs.description)", config: self.configuration, context: self.context, caller: self)
            }
        case .categoryChange:
            Trace.trace(Trace.Level.DEBUG, message: "AudioController audioRouteChanged new category: \(session.category.rawValue)", config: self.configuration, context: self.context, caller: self)
        default: ()
        }
    }
}
