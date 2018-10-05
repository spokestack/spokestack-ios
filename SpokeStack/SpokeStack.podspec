Pod::Spec.new do |s|
  
  s.name     = 'SpokeStack'
  s.version  = '0.0.5'
  s.license  = 'Apache 2.0'
  s.authors  = { 'Pylon, Inc' => 'contact@pylon.com'}
  s.homepage = 'https://github.com/kwylez/spokestack-ios'
  s.source   = { :git => 'https://github.com/kwylez/spokestack-ios.git',
                 :tag => '0.0.5' }
  
  s.summary  = 'SpokeStack Integration'

  s.swift_version = "4.2"

  s.ios.deployment_target = '11.0'

  s.source_files = "SpokeStack/**/*.{swift}"

  s.dependency "!ProtoCompiler-gRPCPlugin", "~> 1.0"

    # The --objc_out plugin generates a pair of .pbobjc.h/.pbobjc.m files for each .proto file.
  s.subspec "Messages" do |ms|
    ms.source_files = "google/**/*.pbobjc.{h,m}"
    ms.header_mappings_dir = "."
    ms.requires_arc = false
    ms.dependency "Protobuf"
  end

  # The --objcgrpc_out plugin generates a pair of .pbrpc.h/.pbrpc.m files for each .proto file with
  # a service defined.
  s.subspec "Services" do |ss|
    ss.source_files = "google/**/*.pbrpc.{h,m}"
    ss.header_mappings_dir = "."
    ss.requires_arc = true
    ss.dependency "gRPC-ProtoRPC"
    ss.dependency "#{s.name}/Messages"
  end

end