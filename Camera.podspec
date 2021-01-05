version = '0.0.14-dev3'

Pod::Spec.new do |s|
  s.name = 'Camera'
  s.version = version
  s.homepage = 'https://github.com/jonbrennecke/Camera'
  s.author = 'Jon Brennecke'
  s.platforms = { :ios => '13.2' }
  s.source = { :git => 'https://github.com/jonbrennecke/Camera.git', :tag => "v#{version}" }
  s.cocoapods_version = '>= 1.2.0'
  s.license = 'AGPL'
  s.summary = 'Swift library of camera and video utilities'
  s.swift_version = '5'
  # s.default_subspec = "Default"

  # s.subspec 'Default' do |ss|
  s.source_files = 'Source/**/*.{swift,h,m}'
  s.dependency 'ImageUtils'
  s.dependency 'VideoEffects'
  # end
end
