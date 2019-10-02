Pod::Spec.new do |s|
  s.name = 'SpokeStack'
  s.version = '2.0.6'
  s.license = 'Apache'
  s.summary = 'Spokestack provides an extensible speech recognition pipeline for the iOS platform.'
  s.homepage = 'https://www.pylon.com'
  s.authors = { 'Spokestack' => 'support@pylon.com' }
  s.source = { :git => 'https://github.com/pylon/spokestack-ios.git', :tag => s.version.to_s }
  s.license = {:type => 'Apache', :file => 'LICENSE'}
  s.ios.deployment_target = '11.0'
  s.swift_version = '4.2'
  s.ios.framework = 'AVFoundation'
  s.exclude_files = 'SpokeStackFrameworkExample/*.*', 'SpokeStackTests/*.*', 'SpokeStack/Info.plist'
  s.source_files = 'SpokeStack/**/*.{swift,h,m,c}'
  s.pod_target_xcconfig = {'SWIFT_INCLUDE_PATHS' => '${SRCROOT}/SpokeStack/VAD/filter_audio/** ${SRCROOT}/SpokeStack/VAD/Wit', 'HEADER_SEARCH_PATHS' => '${SRCROOT}/SpokeStack/VAD/filter_audio/** ${SRCROOT}/SpokeStack/VAD/Wit'}
  s.preserve_paths = 'SpokeStack/**/*.modulemap'
  s.public_header_files = 'SpokeStack/SpokeStack.h'
  s.dependency 'TensorFlowLiteSwift', '~> 1.14.0'
  s.static_framework = true

end
