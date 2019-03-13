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
    
    var sampleRate: Int = 16000
    
    var bufferDuration: TimeInterval = 10
    
    // MARK: Private (properties)
    
    var priorAudioSessionCategory: AVAudioSession.Category?
    var priorAudioSessionMode: AVAudioSession.Mode?
    var priorAudioSessionCategoryOptions: AVAudioSession.CategoryOptions?

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
        do {
            try self.beginAudioSession()
            self.prepareRemoteIOUnit()
        } catch AudioError.audioSessionSetup(let message) {
            self.delegate?.setupFailed(message)
        } catch AudioError.general(let message) {
            self.delegate?.setupFailed(message)
        } catch {
            self.delegate?.setupFailed("An unknown error occured setting the stream")
        }
    }

    // MARK: Public functions

    func startStreaming(context: SpeechContext) -> Void {
        print("AudioController startStreaming")
        do {
            try self.start()
            try self.beginAudioSession()
        } catch AudioError.audioSessionSetup(let message) {
            self.delegate?.setupFailed(message)
        } catch AudioError.general(let message) {
            self.delegate?.setupFailed(message)
        } catch {
            self.delegate?.setupFailed("An unknown error occured starting the stream")
        }
    }

    func stopStreaming(context: SpeechContext) -> Void {
        print("AudioController stopStreaming")
        do {
            try self.stop()
            try self.endAudioSession()
        } catch AudioError.audioSessionSetup(let message) {
            self.delegate?.setupFailed(message)
        } catch {
            self.delegate?.setupFailed("An unknown error occured ending the stream")
        }
    }

    func beginAudioSession() throws {
        print("AudioController beginAudioSession")
        // TODO: https://developer.apple.com/documentation/avfoundation/avaudiosession/responding_to_audio_session_route_changes
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        self.priorAudioSessionCategory = session.category
        self.priorAudioSessionMode = session.mode
        self.priorAudioSessionCategoryOptions = session.categoryOptions
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: self.determineAudioSessionCategoryOptions())
            try session.setPreferredIOBufferDuration(self.bufferDuration)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioError.audioSessionSetup(error.localizedDescription)
        }
    }

    func endAudioSession() throws {
        print("AudioController endAudioSession")
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            if !(session.category == self.priorAudioSessionCategory) {
                try session.setCategory(self.priorAudioSessionCategory!, mode: self.priorAudioSessionMode!, options: self.priorAudioSessionCategoryOptions!)
            }
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            throw AudioError.audioSessionSetup(error.localizedDescription)
        }
    }

    func determineAudioSessionCategoryOptions() -> AVAudioSession.CategoryOptions {
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        for description in session.currentRoute.outputs {
            if (description.portType == AVAudioSession.Port.headphones)
                || (description.portType == AVAudioSession.Port.bluetoothLE)
                || (description.portType == AVAudioSession.Port.bluetoothHFP)
                || (description.portType == AVAudioSession.Port.bluetoothA2DP)
                || (description.portType == AVAudioSession.Port.headsetMic) {
                // TODO: this is cribbing from the issues that led to the PR at https://github.com/wenkesj/react-native-voice/pull/103/files. Are other category options needed? Inputs vs outputs?
                return AVAudioSession.CategoryOptions.allowBluetoothA2DP
            }
        }
        return AVAudioSession.CategoryOptions.defaultToSpeaker
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
