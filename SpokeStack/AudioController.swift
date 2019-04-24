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

class AudioController {
    
    // MARK: Public (properties)
    
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
        if let riou = remoteIOUnit {
            AudioComponentInstanceDispose(riou)
        }
        if let ioUnit: AudioComponentInstance = self.remoteIOUnit {
            AudioComponentInstanceDispose(ioUnit)
        }
    }
    
    init(delegate: PipelineDelegate?) {
        print("AudioController init")
        self.pipelineDelegate = delegate
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
        if let riou = remoteIOUnit {
            status = AudioOutputUnitStop(riou)
        }
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
}
