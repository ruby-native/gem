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
require "active_record"

Dummy::Application.initialize!

# Explicitly require the model since engine autoloading may not work in the minimal dummy app.
require_relative "../app/models/ruby_native/iap/purchase_intent"

# Set up in-memory database for PurchaseIntent tests.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :ruby_native_purchase_intents, force: true do |t|
    t.string :uuid, null: false
    t.string :customer_id, null: false
    t.string :product_id
    t.string :success_path
    t.string :status, null: false, default: "pending"
    t.string :environment
    t.timestamps
  end
  add_index :ruby_native_purchase_intents, :uuid, unique: true
  add_index :ruby_native_purchase_intents, :customer_id
end
