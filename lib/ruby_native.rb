require "ruby_native/version"
require "ruby_native/helper"
require "ruby_native/native_detection"
require "ruby_native/oauth_middleware"
require "ruby_native/engine"

module RubyNative
  mattr_accessor :config

  def self.load_config
    path = Rails.root.join("config", "ruby_native.yml")
    return unless path.exist?

    self.config = YAML.load_file(path).deep_symbolize_keys
    self.config[:app] ||= {}
    self.config[:app][:name] ||= "Ruby Native"
    self.config[:auth] ||= {}
  end
end
