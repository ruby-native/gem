require "ruby_native/version"
require "ruby_native/helper"
require "ruby_native/native_detection"
require "ruby_native/engine"

module RubyNative
  mattr_accessor :config

  def self.load_config
    path = Rails.root.join("config", "ruby_native.yml")
    self.config = YAML.load_file(path).deep_symbolize_keys if path.exist?
  end
end
