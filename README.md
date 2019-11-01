# Spokestack iOS

Spokestack provides an extensible speech recognition pipeline for the iOS
platform. It includes a variety of built-in speech processors for Voice
Activity Detection (VAD), wakeword activation, and Automatic Speech Recognition (ASR).

## Installation
[![](https://img.shields.io/cocoapods/v/Spokestack-iOS.svg)](https://cocoapods.org/pods/Spokestack-iOS)

`pod 'Spokestack-iOS'`

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Spokestack into your Xcode project using CocoaPods, specify it in your Podfile:

## Release
  1. Ensure that CocoaPods has been installed via `gem`, not via `brew`
  2. Increment the `podspec` version in `Spokestack-iOS.podspec`
  3. `git commit -a -m 'YOUR_COMMIT_MESSAGE' && git tag YOUR_PODSPEC_VERSION && git push --origin`
  4. `pod spec lint --use-libraries --allow-warnings --use-modular-headers`, which should pass all checks 
  6. `pod trunk register YOUR_EMAIL --description='release YOUR_PODSPEC_VERSION'`
  7. `pod trunk push  --use-libraries --allow-warnings --use-modular-headers`

## License
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)

Copyright 2018 Pylon, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
