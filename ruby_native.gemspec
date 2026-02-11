require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native"
  spec.version = RubyNative::VERSION
  spec.authors = ["Joe Masilotti"]
  spec.email = ["joe@masilotti.com"]

  spec.summary = "Turn your existing Rails app into a native iOS and Android app."
  spec.description = "Turn your existing Rails app into a native iOS and Android app with Ruby Native."
  spec.homepage = "https://github.com/Ruby-Native/gem"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
end
