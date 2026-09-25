require "ruby_native/cli/command"

module RubyNative
  class CLI
    # The reviewer's sign-in, staged with rubynative.com and written to App
    # Store Connect when the listing is published. It stays out of
    # config/ruby_native_listing.yml on purpose: that file is committed.
    class DemoAccount < Command
      def run
        ensure_authenticated!
        app_id = app_id!

        unless positional.first == "set" && flag("name")
          puts "Usage: ruby_native demo_account set --name=EMAIL --password=SECRET [--notes=\"...\"] [--not-required]"
          exit 1
        end

        finish(self.class.set(app_id, name: flag("name"), password: flag("password"), notes: flag("notes"), required: !@argv.include?("--not-required")))
      end

      def self.set(app_id, name:, password: nil, notes: nil, required: true)
        demo = { name: name, required: required }
        demo[:password] = password unless password.nil?
        demo[:notes] = notes unless notes.nil?

        result = Mcp::Platform.patch("/api/v1/apps/#{app_id}/listing", { demo_account: demo })
        return failure(result) unless result.ok?

        account = result.value["demo_account"] || {}
        text = "Demo account #{account["name"]}#{account["password_set"] ? "" : " (no password set)"} saved. " \
               "It reaches App Store Connect when the listing is published."
        success(text, result.value)
      end
    end
  end
end
