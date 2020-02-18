//
//  AppDelegate.swift
//  SpokestackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var newBluetoothAvailable: Bool?
    var usingBluetoothInput: Bool?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteChanged),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        let sessionCategory: AVAudioSession.Category = .playAndRecord
        let sessionOptions: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]
        do {
            // try session.setPreferredIOBufferDuration(0.01)
            if ((session.category != sessionCategory) || !(session.categoryOptions.contains(sessionOptions))) { // TODO: add (session.ioBufferDuration != self.bufferDuration) once mode-based wakeword is enabled
                try session.setCategory(sessionCategory, mode: .default, options: sessionOptions)
                // TODO: The below line implicitly disables HFP output. Investigate buffer duration versus bluetooth output settings.
                // try session.setPreferredIOBufferDuration(self.bufferDuration)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            }
        } catch {
            print("AppDelegate application error when setting AudioSession category")
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    @objc private func audioRouteChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                return
        }
        switch reason {
        case .newDeviceAvailable:
            self.newBluetoothAvailable = true
            // useBluetoothHFPInput()
            break
        case .oldDeviceUnavailable:
            self.newBluetoothAvailable = false
            self.usingBluetoothInput = false
        default:
            break
        }
    }
    
    private func useBluetoothHFPInput() {
        print("AppDelegate useBluetoothHFPInput")
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else {
            return
        }
        for input in inputs {
            if (input.portType == AVAudioSession.Port.bluetoothHFP) {
                do {
                    try session.setPreferredInput(input)
                    self.newBluetoothAvailable = false
                } catch {
                    print("AppDelegate useBluetoothHFPInputIfAvailable error")
                }
            }
        }
    }
    
    @objc public func useBluetoothHFPInputIfAvailable() {
        print("AppDelegate useBluetoothHFPInputIfAvailable")
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            self.useBluetoothHFPInput()
            self.usingBluetoothInput = true
        } catch {
            print("AppDelegate useBluetoothHFPInputIfAvailable error when setting AudioSession category")
        }
    }
    
    @objc public func useA2DPOutputIfAvailable() {
        print("AppDelegate useA2DPOutputIfAvailable")
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AppDelegate useA2DPOutputIfAvailable error when setting AudioSession category")
        }
    }
    
    @objc public func switchInputsIfAvailable() {
        print("AppDelegate switchInputsIfAvailable")
        if self.newBluetoothAvailable ?? false {
            print("AppDelegate switchInputsIfAvailable newBluetoothAvailable")
            if self.usingBluetoothInput ?? false {
                print("AppDelegate switchInputsIfAvailable usingBluetoothInput")
            } else {
                self.useBluetoothHFPInputIfAvailable()
            }
        } else {
            self.useA2DPOutputIfAvailable()
        }
    }
}

