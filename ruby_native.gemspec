require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native"
  spec.version = RubyNative::VERSION
  spec.authors = ["Joe Masilotti"]
  spec.email = ["joe@masilotti.com"]

  spec.summary = "Turn your existing Rails app into a native iOS and Android app."
  spec.description = "Turn your existing Rails app into a native iOS and Android app with Ruby Native."
  spec.homepage = "https://github.com/ruby-native/gem"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["{app,config,exe,lib}/**/*", "LICENSE", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["ruby_native"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "rqrcode", "~> 3.0"
end
