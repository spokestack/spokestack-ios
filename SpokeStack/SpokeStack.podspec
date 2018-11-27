Pod::Spec.new do |s|
  s.name = 'SpokeStack'
  s.version = '0.0.1'
  s.license = 'Apache'
  s.summary = 'Spokestack provides an extensible speech recognition pipeline for the iOS platform.'
  s.homepage = 'https://www.pylon.com'
  s.authors = { 'Spokestack' => 'support@pylon.com' }
  s.source = { :git => 'https://github.com/kwylez/spokestack-ios.git', :tag => s.version }

  s.ios.deployment_target = '11.0'

  s.source_files = 'SpokeStack/*'
  s.exclude_files = 'SpokeStackFrameworkExample/*.*'
  # s.xcconfig  = {
  #   'VALID_ARCHS' => 'armv7 armv7s arm64, arm64e'
  # }
end