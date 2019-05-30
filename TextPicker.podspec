Pod::Spec.new do |s|
  s.name                      = "TextPicker"
  s.version                   = "0.1"
  s.summary                   = "TextPicker"
  s.homepage                  = "https://github.com/NotTooBadSoftware/TextPicker"
  s.license                   = { :type => "MIT", :file => "LICENSE" }
  s.author                    = { "Kare Morstol" => "kare@nottoobadsoftware.com" }
  s.source                    = { :git => "https://github.com/NotTooBadSoftware/TextPicker.git", :tag => s.version.to_s }
  s.ios.deployment_target     = "8.0"
  s.tvos.deployment_target    = "9.0"
  s.watchos.deployment_target = "2.0"
  s.osx.deployment_target     = "10.10"
  s.source_files              = "Sources/**/*"
  s.frameworks                = "Foundation"
end
