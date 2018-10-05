Pod::Spec.new do |s|
  
  s.name     = 'SpokeStack'
  s.version  = '0.0.2'
  s.license  = 'Apache 2.0'
  s.authors  = { 'Pylon, Inc' => 'contact@pylon.com'}
  s.homepage = 'https://github.com/kwylez/spokestack-ios'
  s.source   = { :git => 'https://github.com/kwylez/spokestack-ios.git',
                 :tag => '#{s.version}' }
  
  s.summary  = 'SpokeStack Integration'

  s.swift_version = "4.2"

  s.ios.deployment_target = '11.0'

  s.source_files = "SpokeStack/**/*.{swift}"

end