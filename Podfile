# use cocoapods cdn for faster builds. if you're on cocoapods 1.7 or earlier, time to upgrade!
source 'https://cdn.cocoapods.org/'

# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'Spokestack' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Spokestack
  pod 'TensorFlowLiteSwift', '~> 2.3.0'
  pod 'filter_audio', '~> 0.4.3', :modular_headers => true

  target 'SpokestackTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'SpokestackFrameworkExample' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for SpokestackFrameworkExample

end
