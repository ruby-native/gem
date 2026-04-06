ENV["RAILS_ENV"] = "test"

require "minitest/autorun"
require "rails"
require "action_view"
require "action_view/test_case"
require "rails/test_help"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.root = File.expand_path("dummy", __dir__)

    # Minimal middleware for testing.
    config.api_only = false
    config.secret_key_base = "test-secret-key-base"
  end
end

# Write a minimal config file for the dummy app.
dummy_config_dir = File.expand_path("dummy/config", __dir__)
FileUtils.mkdir_p(dummy_config_dir)
File.write(File.join(dummy_config_dir, "ruby_native.yml"), <<~YAML)
  app:
    name: Test App
  appearance:
    tint_color: "#007AFF"
    background_color: "#FFFFFF"
  tabs:
    - title: Home
      path: /
      icon: house
  auth:
    oauth_paths:
      - /auth/test_provider
YAML

require "ruby_native"

Dummy::Application.initialize!
