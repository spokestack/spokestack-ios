# Spokestack iOS

Spokestack provides an extensible speech recognition pipeline for the iOS
platform. It includes a variety of built-in speech processors for Voice
Activity Detection (VAD) and Automatic Speech Recognition (ASR) via popular
speech recognition services, such as the Google Speech API.

## Installation
[![](https://img.shields.io/cocoapods/v/SpokeStack.svg)](https://cocoapods.org/pods/SpokeStack)

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. For usage and installation instructions, visit their website. To integrate Spokestack into your Xcode project using CocoaPods, specify it in your Podfile:

`pod 'Spokestack', '~> 0.0.2'`

## Release
  1. Ensure that CocoaPods has been installed via `gem`, not via `brew`
  2. Increment the `podspec` version in `SpokeStack.podspec`
  3. `git commit -a -m 'YOUR_COMMIT_MESSAGE' && git tag YOUR_PODSPEC_VERSION && git push --origin`
  4. `pod spec lint`, which should pass all but one checks (expect `ERROR | [iOS] xcodebuild: Returned an unsuccessful exit code. You can use `--verbose` for more information.`)
  5. edit `/Library/Ruby/Gems/YOUR_RUBY_VERSION/gems/cocoapods-trunk-YOUR_COCOAPODS_VERSION/lib/pod/command/trunk/push.rb`, comment out `validate_podspec_files` (https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/command/repo/push.rb#L77)
  6. `pod trunk register YOUR_EMAIL --description='release YOUR_PODSPEC_VERSION'`
  7. `pod trunk push SpokeStack.podspec`
  8. remove comment inserted in step 5.
Due to static library dependencies not distributed as universal binaries, there’s no way to make `pod spec lint` or `pod lib lint` complete successfully. Aside from `x86_64`/`iphonesimulator` not being a supported architecture, the `podspec` is complete and correct. This release approach, while not conforming to the standard CocoaPods release process, is understood to be valid (https://github.com/CocoaPods/CocoaPods/issues/5801#issuecomment-244520442).

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
