version = '0.0.8'

Pod::Spec.new do |s|
  s.name = 'Camera'
  s.version = version
  s.homepage = 'https://github.com/jonbrennecke/Camera'
  s.author = 'Jon Brennecke'
  s.platforms = { :ios => '13.0' }
  s.source = { :git => 'https://github.com/jonbrennecke/Camera.git', :tag => "v#{version}" }
  s.cocoapods_version = '>= 1.2.0'
  s.license = 'AGPL'
  s.summary = 'Swift library of camera and video utilities'
  s.swift_versions = '5'
  s.default_subspec = "Default"

  s.subspec 'Default' do |ss|
    ss.source_files = 'Source/**/*.{swift,h,m}'
    ss.dependency 'ImageUtils', '0.0.5'
    ss.dependency 'VideoEffects', '0.0.30'
  end
end
