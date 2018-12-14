Pod::Spec.new do |s|
  s.name = 'SpokeStack'
  s.version = '0.0.1'
  s.license = 'Apache'
  s.summary = 'Spokestack provides an extensible speech recognition pipeline for the iOS platform.'
  s.homepage = 'https://www.pylon.com'
  s.authors = { 'Spokestack' => 'support@pylon.com' }
  s.source = { :git => 'https://github.com/pylon/spokestack-ios.git', :tag => '0.0.1' }
  s.license = 'Apache'
  s.ios.deployment_target = '11.0'
  s.swift_version = '4.0'
  s.ios.framework = 'AVFoundation'
  s.source_files = 'SpokeStack/*.{h,m,o,swift}'
  s.exclude_files = 'SpokeStackFrameworkExample/*.*, SpokeStackTests/*.*, SpokeStack/Info.plist'
  s.resource = 'Frameworks/gRPC/gRPCCertificates.bundle'
  s.preserve_paths = 'Frameworks/BoringSSL-GRPC/openssl.framework', 'Frameworks/googleapis/googleapis.framework', 'Frameworks/gRPC/GRPCClient.framework', 'Frameworks/gRPC-Core/grpc.framework', 'Frameworks/gRPC-ProtoRPC/ProtoRPC.framework', 'Frameworks/gRPC-RxLibrary/RxLibrary.framework', 'Frameworks/nanopb/nanopb.framework', 'Frameworks/Protobuf/Protobuf.framework'

  s.vendored_frameworks = 'Frameworks/BoringSSL-GRPC/openssl.framework', 'Frameworks/googleapis/googleapis.framework', 'Frameworks/gRPC/GRPCClient.framework', 'Frameworks/gRPC-Core/grpc.framework', 'Frameworks/gRPC-ProtoRPC/ProtoRPC.framework', 'Frameworks/gRPC-RxLibrary/RxLibrary.framework', 'Frameworks/nanopb/nanopb.framework', 'Frameworks/Protobuf/Protobuf.framework'
  s.xcconfig  = {
    'VALID_ARCHS' => 'armv7 armv7s arm64 arm64e',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) GPB_USE_PROTOBUF_FRAMEWORK_IMPORTS=1 PB_FIELD_32BIT=1 PB_NO_PACKED_STRUCTS=1'
  }
end
