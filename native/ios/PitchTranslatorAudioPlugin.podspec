Pod::Spec.new do |s|
  s.name             = 'PitchTranslatorAudioPlugin'
  s.version          = '0.1.0'
  s.summary          = 'Realtime microphone pitch capture for Pitch Translator.'
  s.description      = 'Flutter iOS plugin wrapper that bridges AVAudioEngine input into the shared PT DSP core.'
  s.homepage         = 'https://example.invalid/pitch-translator'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Pitch Translator' => 'dev@pitchtranslator.local' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.source_files = [
    'Sources/**/*.{swift,h,m,mm}',
    '../../dsp/include/pt_dsp/**/*.h',
    '../../dsp/src/**/*.{c,cc,cpp,h,hpp}'
  ]

  s.public_header_files = 'Sources/PitchTranslatorDSPBridge.h'
  s.header_mappings_dir = '../../dsp/include'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/../../dsp/include'
  }

  s.frameworks = 'AVFoundation'
end
