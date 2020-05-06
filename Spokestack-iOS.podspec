Pod::Spec.new do |s|
  s.name = 'Spokestack-iOS'
  s.module_name = 'Spokestack'
  s.version = '9.0.1'
  s.license = 'Apache'
  s.summary = 'Spokestack provides an extensible speech recognition pipeline for the iOS platform.'
  s.homepage = 'https://www.spokestack.io'
  s.authors = { 'Spokestack' => 'support@spokestack.io' }
  s.source = { :git => 'https://github.com/spokestack/spokestack-ios.git', :tag => s.version.to_s }
  s.license = {:type => 'Apache', :file => 'LICENSE'}
  s.ios.deployment_target = '11.0'
  s.swift_version = '5.0'
  s.ios.framework = 'AVFoundation', 'CoreML'
  s.exclude_files = 'SpokestackFrameworkExample/*.*', 'SpokestackTests/*.*', 'Spokestack/Info.plist'
  s.source_files = 'Spokestack/**/*.{swift,h,m,c}'
  s.pod_target_xcconfig = {'SWIFT_INCLUDE_PATHS' => '$(SRCROOT)/Spokestack/VAD/Wit', 'HEADER_SEARCH_PATHS' => '$(SRCROOT)/Spokestack/VAD/Wit'}
  s.preserve_paths = 'Spokestack/**/*.modulemap'
  s.public_header_files = 'Spokestack/Spokestack.h'
  s.dependency 'TensorFlowLiteSwift', '~> 1.14.0'
  s.dependency 'filter_audio', '~> 0.4.3'
  s.static_framework = true

end
