//
//  AudioController.swift
//  SpokeStack
//
//  Created by Cory D. Wiles on 9/28/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation
import AVFoundation

let audioProcessingQueue: DispatchQueue = DispatchQueue(label: "com.pylon.audio.callback")

func recordingCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    guard let remoteIOUnit: AudioComponentInstance = AudioController.shared.remoteIOUnit else {
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
    
    let data: Data = Data(bytes: buffers[0].mData!, count: Int(buffers[0].mDataByteSize))
    
    audioProcessingQueue.sync {
        AudioController.shared.delegate?.processSampleData(data)
    }
    
    return noErr
}

class AudioController {
    
    // MARK: Public (properties)
    
    static let shared: AudioController = AudioController()
    
    weak var delegate: AudioControllerDelegate?
    weak var pipelineDelegate: PipelineDelegate?
    
    var sampleRate: Int = 16000
    
    var bufferDuration: TimeInterval = 10
    
    // MARK: Private (properties)
    
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
        print("AudioController deinit")
        AudioComponentInstanceDispose(remoteIOUnit!)
        if let ioUnit: AudioComponentInstance = self.remoteIOUnit {
            AudioComponentInstanceDispose(ioUnit)
        }
    }
    
    init() {
        print("AudioController init")
        switch AVAudioSession.sharedInstance().category {
        case AVAudioSession.Category.record:
            break
        case AVAudioSession.Category.playAndRecord:
            break
        default:
            self.pipelineDelegate?.setupFailed("Incompatible AudioSession category is set.")
        }
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteChanged),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
        self.prepareRemoteIOUnit()
    }
    
    // MARK: Public functions
    
    func startStreaming(context: SpeechContext) -> Void {
        print("AudioController startStreaming")
        do {
            try self.start()
        } catch AudioError.audioSessionSetup(let message) {
            self.pipelineDelegate?.setupFailed(message)
        } catch AudioError.general(let message) {
            self.pipelineDelegate?.setupFailed(message)
        } catch {
            self.pipelineDelegate?.setupFailed("An unknown error occured starting the stream")
        }
    }
    
    func stopStreaming(context: SpeechContext) -> Void {
        print("AudioController stopStreaming")
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
        status = AudioOutputUnitStop(remoteIOUnit!)
        if status != noErr {
            throw AudioError.audioSessionSetup("AudioOutputUnitStop returned " + status.description)
        }
        return status
    }
    
    private func printAudioSessionDebug() {
        let session = AVAudioSession.sharedInstance()
        let sss: String = session.category.rawValue
        let sco: String = session.categoryOptions.rawValue.description
        let sioap: String = session.isOtherAudioPlaying.description
        print("AudioController printAudioSessionDebug current category: " + sss + " options: " + sco + " isOtherAudioPlaying: " + sioap + " bufferduration " + session.ioBufferDuration.description)
        let route_inputs: String = session.currentRoute.inputs.debugDescription
        let route_outputs: String = session.currentRoute.outputs.debugDescription
        let preferredInput: String = session.preferredInput.debugDescription
        let usb_outputs: String = session.outputDataSources?.debugDescription ?? "none"
        let inputs: String = session.availableInputs?.debugDescription ?? "none"
        print("AudioController printAudioSessionDebug inputs: " + inputs + " preferredinput: " + preferredInput + " input: " + route_inputs + " output: " + route_outputs + " usb_outputs: " + usb_outputs)
    }
    
    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        print("AudioController audioRouteChanged reason: " + reasonValue.description + " notification: " + userInfo.debugDescription)
        printAudioSessionDebug()
        let session = AVAudioSession.sharedInstance()
        switch reason {
        case .newDeviceAvailable:
            print("AudioController audioRouteChanged new output: " + session.currentRoute.outputs.description)
        case .oldDeviceUnavailable:
            if let previousRoute =
                userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                print("AudioController audioRouteChanged old output: " + previousRoute.outputs.description)
            }
        case .categoryChange:
            print("AudioController audioRouteChanged new category: " + session.category.rawValue)
        default: ()
        }
    }
    
    @discardableResult
    private func prepareRemoteIOUnit() -> OSStatus {
        
        // MARK: prepare RemoteIO unit component
        
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
        asbd.mSampleRate = Double(self.sampleRate)
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
}
