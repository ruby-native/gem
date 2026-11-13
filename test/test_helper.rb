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

# Captured before any test reads the config; see RubyNative.config.
CONFIG_LOADED_AT_BOOT = RubyNative.instance_variable_defined?(:@config)

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
    t.string :restored_transaction_id
    t.timestamps
  end
  add_index :ruby_native_purchase_intents, :uuid, unique: true
  add_index :ruby_native_purchase_intents, :customer_id

  create_table :users, force: true do |t|
    t.string :name
  end

  # Same columns as the Action Push Native install migration.
  create_table :action_push_native_devices, force: true do |t|
    t.string :name
    t.string :platform, null: false
    t.string :token, null: false
    t.belongs_to :owner, polymorphic: true
    t.timestamps
  end
end

class User < ActiveRecord::Base
  has_many :push_devices, class_name: "ApplicationPushDevice", as: :owner, dependent: :destroy
end

# Stands in for ActionPushNative::Device, which the gem does not depend on.
# Keep the platform enum in step with it.
class ApplicationPushDevice < ActiveRecord::Base
  self.table_name = "action_push_native_devices"

  belongs_to :owner, polymorphic: true, optional: true

  enum :platform, {apple: "apple", google: "google"}, validate: true
end

# The push endpoint inherits from the host app's ApplicationController.
class ApplicationController < ActionController::Base
  cattr_accessor :require_sign_in, default: false

  # A generated Rails app gets this from the Action Controller railtie.
  protect_from_forgery with: :exception

  before_action(if: :require_sign_in) { head :unauthorized unless current_user }

  private

  def current_user
    User.find_by(id: cookies[:user_id])
  end
end
