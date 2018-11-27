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
  s.exclude_files = 'SpokeStackFrameworkExample/*.*, SpokeStackTests/*.*'
  s.ios.vendored_frameworks = 'Frameworks/BoringSSL-GRPC/openssl.framework', 'Frameworks/googleapis/googleapis.framework', 'Frameworks/gRPC/GRPCClient.framework', 'Frameworks/gRPC-Core/grpc.framework', 'Frameworks/gRPC-ProtoRPC/ProtoRPC.framework', 'Frameworks/gRPC-RxLibrary/RxLibrary.framework', 'Frameworks/nanopb/nanopb.framework', 'Frameworks/Protobuf/Protobuf.framework'
  # s.vendored_frameworks = 'Frameworks/googleapis/googleapis.framework'
  s.xcconfig  = {
    'VALID_ARCHS' => 'armv7 armv7s arm64 arm64e'
  }
end