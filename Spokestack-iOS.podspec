Pod::Spec.new do |s|
  s.name = 'Spokestack-iOS'
  s.module_name = 'Spokestack'
  s.version = '14.0.5'
  s.license = 'Apache'
  s.summary = 'Spokestack provides an extensible speech interface for the iOS platform.'
  s.homepage = 'https://www.spokestack.io'
  s.authors = { 'Spokestack' => 'support@spokestack.io' }
  s.source = { :git => 'https://github.com/spokestack/spokestack-ios.git', :tag => s.version.to_s, :branch => 'release' }
  s.license = {:type => 'Apache', :file => 'LICENSE'}
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.0'
  s.ios.framework = 'AVFoundation', 'CoreML'
  s.exclude_files = 'SpokestackFrameworkExample/*.*', 'SpokestackTests/*.*', 'Spokestack/Info.plist'
  s.source_files = 'Spokestack/**/*.{swift,h,m,c}'
  s.public_header_files = 'Spokestack/Spokestack.h'
  s.dependency 'TensorFlowLiteSwift', '~> 2.3.0'
  s.dependency 'filter_audio', '~> 0.5.0'
  s.static_framework = true
  # Exclude Apple Silicon simulator architecture from build list, but still build for Apple Silicon physical.
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64', 'EXCLUDED_ARCHS[sdk=watchsimulator*]' => 'arm64', 'EXCLUDED_ARCHS[sdk=appletvsimulator*]' => 'arm64'}
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64', 'EXCLUDED_ARCHS[sdk=watchsimulator*]' => 'arm64', 'EXCLUDED_ARCHS[sdk=appletvsimulator*]' => 'arm64'}

end
