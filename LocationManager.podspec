Pod::Spec.new do |s|
  s.name             = "LocationManager"
  s.version          = "2.1.0"
  s.summary          = "CoreLocation wrapper for handling locations with ease."

  s.description      = <<-DESC
                        CoreLocation wrapper for handling locations with ease. Get location and attach location observers.
                       DESC

  s.homepage         = "https://github.com/futuredapp/LocationManager"
  s.license          = 'MIT'
  s.author           = { "Jakub Knejzlik" => "jakub.knejzlik@gmail.com" }
  s.source           = { :git => "https://github.com/futuredapp/LocationManager.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/Futuredapps'

  s.platform         = :ios, '11.0'
  s.swift_versions   = ['4.2', '5.0', '5.1', '5.2']

  s.source_files     = 'Pod/Classes/**/*'

  s.dependency 'PromiseKit', '~> 6.11'
end
