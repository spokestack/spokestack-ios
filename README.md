# Spokestack iOS

Spokestack provides an extensible speech recognition pipeline for the iOS
platform. It includes a variety of built-in speech processors for Voice
Activity Detection (VAD), wakeword activation, and Automatic Speech Recognition (ASR).

<!--ts-->
## Table of Contents
* [Features](#features)
* [Installation](#installation)
* [Documentation](#Documentation)
* [Reference Implementation](#Reference implementation)
* [Deployment](#Deployment)
* [License](#license)
<!--te-->

## Features

  - Voice activity detection
  - Wakeword activation with two different implementations
  - Simplified Automated Speech Recognition interface
  - Speech pipeline seamlessly integrates VAD-triggered wakeword detection using on-device machine learning models with transcribing utterances using platform Automated Speech Recognition
  - On-device Natural Language Understanding utterance classifier
  - Simple Text to Speech API

## Installation
[![](https://img.shields.io/cocoapods/v/Spokestack-iOS.svg)](https://cocoapods.org/pods/Spokestack-iOS)

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Spokestack into your Xcode project using CocoaPods, specify it in your Podfile:

`pod 'Spokestack-iOS'`

## Documentation

### Getting Started, Cookbooks, and Conceptual Guides

[Step-by-step introduction](https://spokestack.io/docs/iOS/getting-started), [common usage patterns](https://spokestack.io/docs/iOS/cookbook), and [discussion of concepts](https://spokestack.io/docs/Concepts/pipeline-configuration) used by the library, [design guides for voice interfaces](https://spokestack.io/docs/Design/getting-started), and [the Android library](https://spokestack.io/docs/Android/getting-started) may all be found [on our website](https://spokestack.io/docs).

### API Reference

API reference is [available on Github](https://spokestack.github.io/spokestack-ios/index.html).

## Reference implementation

The `SpokestackFrameworkExample` project contains reference implementations for how to use the Spokestack library, along with runnable examples of the wakeword and ASR components. Each component has a corresponding screen from the main screen, and can be started, stopped, or synthesized, as appropriate. The component screens have full debug tracing enabled, so the system control logic and debug events will appear in the XCode Console.

## Deployment

### Preconditions

  0. Ensure that `git lfs` has been installed: https://git-lfs.github.com/. This is used to manage the storage of the large model and metadata files in `SpokestackFrameworkExample`.
  1. Ensure that CocoaPods has been installed: `gem install cocoapods` ([not via `brew`](https://github.com/CocoaPods/CocoaPods/issues/8955)).
  2. Ensure that you are registered in CocoaPods: `pod trunk register YOUR_EMAIL --description='release YOUR_PODSPEC_VERSION'`

### Process
  1. Increment the `podspec` version in `Spokestack-iOS.podspec`
  2. `git commit -a -m 'YOUR_COMMIT_MESSAGE' && git tag YOUR_PODSPEC_VERSION && git push --origin`
  3. `pod spec lint --use-libraries --allow-warnings --use-modular-headers`, which should pass all checks 
  4. `pod trunk push  --use-libraries --allow-warnings --use-modular-headers`

## License
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](https://opensource.org/licenses/Apache-2.0)

Copyright 2020 Spokestack, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
