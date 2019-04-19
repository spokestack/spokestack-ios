//
//  AppDelegate.swift
//  SpokeStackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(audioRouteChanged),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        let sessionCategory: AVAudioSession.Category = .ambient
        let sessionOptions: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker, .allowBluetooth]
        do {
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
        let session = AVAudioSession.sharedInstance()
        switch reason {
        case .newDeviceAvailable:
            guard let inputs = session.availableInputs else {
                return
            }
            for input in inputs {
                if (input.portType == AVAudioSession.Port.bluetoothHFP) {
                    do {
                        try session.setPreferredInput(input)
                    } catch {
                    }
                }
            }
        default:
            break
        }
    }
}

