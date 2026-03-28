require "ruby_native/version"
require "ruby_native/helper"
require "ruby_native/native_version"
require "ruby_native/native_detection"
require "ruby_native/inertia_support"
require "ruby_native/oauth_middleware"
require "ruby_native/tunnel_cookie_middleware"
require "ruby_native/iap/event"
require "ruby_native/iap/verifiable"
require "ruby_native/iap/decodable"
require "ruby_native/iap/normalizable"
require "ruby_native/iap/apple_webhook_processor"
require "ruby_native/engine"

module RubyNative
  mattr_accessor :config
  mattr_accessor :subscription_callbacks, default: []

  def self.on_subscription_change(&block)
    subscription_callbacks << block
  end

  def self.fire_subscription_callbacks(event)
    subscription_callbacks.each { |cb| cb.call(event) }
  end

  def self.load_config
    path = Rails.root.join("config", "ruby_native.yml")
    return unless path.exist?

    self.config = YAML.load_file(path).deep_symbolize_keys
    self.config[:app] ||= {}
    self.config[:app][:name] ||= "Ruby Native"
    self.config[:app][:entry_path] ||= self.config.dig(:tabs, 0, :path) || "/"
    self.config[:auth] ||= {}
  end
end
