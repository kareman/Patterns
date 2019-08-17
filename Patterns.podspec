Pod::Spec.new do |s|
  s.name                      = "Patterns"
  s.version                   = "0.1.0"
  s.summary                   = "A Swift alternative to regex"
  s.homepage                  = "https://github.com/kareman/Patterns"
  s.license                   = { :type => "MIT", :file => "LICENSE" }
  s.author                    = { "Kare Morstol" => "kare@nottoobadsoftware.com" }
  s.source                    = { :git => "https://github.com/kareman/Patterns.git", :tag => s.version.to_s }
  s.ios.deployment_target     = "8.0"
  s.tvos.deployment_target    = "9.0"
  s.watchos.deployment_target = "2.0"
  s.osx.deployment_target     = "10.10"
  s.source_files              = "Sources/**/*"
  s.frameworks                = "Foundation"
end
