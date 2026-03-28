require "rails/generators"
require "rails/generators/migration"

module RubyNative
  module Generators
    class IapGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def copy_migration
        migration_template "create_ruby_native_purchase_intents.rb",
          "db/migrate/create_ruby_native_purchase_intents.rb"
      end

      def print_next_steps
        say ""
        say "Ruby Native IAP installed!", :green
        say ""
        say "  1. Run migrations: bin/rails db:migrate"
        say "  2. Add your callback in config/initializers/ruby_native.rb:"
        say ""
        say '     RubyNative.on_subscription_change do |event|'
        say '       user = User.find_by(id: event.owner_token)'
        say '       user&.update!(subscribed: event.active?)'
        say '     end'
        say ""
        say "  3. Set your App Store Server Notification URL to:"
        say "     https://yourapp.com/native/webhooks/apple"
        say ""
      end
    end
  end
end
