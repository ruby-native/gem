require_relative "lib/ruby_native/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_native"
  spec.version = RubyNative::VERSION
  spec.authors = ["Joe Masilotti"]
  spec.email = ["joe@masilotti.com"]

  spec.summary = "Native bridge helpers for Ruby Native apps."
  spec.description = "A Rails engine providing native detection, configuration, push device registration, and view helpers for Ruby Native iOS and Android apps."
  spec.homepage = "https://github.com/joemasilotti/ruby-native"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
end
