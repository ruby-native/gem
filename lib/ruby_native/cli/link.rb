require "ruby_native/cli/command"
require "ruby_native/cli/mcp/platform"

module RubyNative
  class CLI
    # Links this project to an app on rubynative.com by writing
    # `ruby_native.app_id` into config/ruby_native.yml. Every command that
    # talks to rubynative.com reads it from there. Deploy used to be the only
    # way to link, which put the first honest status read behind a build.
    class Link < Command
      def run
        ensure_authenticated!
        return finish(self.class.link(positional.first || flag("app"))) unless @argv.include?("--new")

        name, url = flag("name"), flag("url")
        if name.to_s.strip.empty? || url.to_s.strip.empty?
          puts "Usage: ruby_native link --new --name=\"App name\" --url=https://example.com"
          exit 1
        end
        finish(self.class.create(name: name, url: url))
      end

      # Creates the app on the account and links it, so an agent never sends
      # the person to Create your app.
      def self.create(name:, url:)
        result = Mcp::Platform.post("/api/v1/apps", { name: name, url: url })
        return failure(result) unless result.ok?

        app = result.value
        Mcp::Platform.write_app_id(app["public_id"])
        success("Created #{app["name"]} (#{app["public_id"]}) for #{app["url"]} and linked it. Wrote ruby_native.app_id to #{Mcp::Platform::CONFIG_PATH}.",
          { "app_id" => app["public_id"], "name" => app["name"], "url" => app["url"] })
      end

      def self.link(app_id = nil)
        result = Mcp::Platform.get("/api/v1/apps")
        return failure(result) unless result.ok?

        apps = Array(result.value)
        return Outcome.new(ok: false, text: "No apps on this account yet. Create one with `ruby_native link --new --name=\"App name\" --url=https://example.com`.", data: { "apps" => [] }) if apps.empty?

        app = if app_id.to_s.strip.empty?
          apps.one? ? apps.first : nil
        else
          apps.find { |candidate| candidate["public_id"] == app_id.to_s.strip }
        end

        unless app
          lines = [ app_id ? "No app #{app_id.inspect} on this account. Pick one:" : "Which app? Run `ruby_native link APP_ID` with one of these:" ]
          apps.each { |candidate| lines << "  #{candidate["public_id"]}  #{candidate["name"]}#{"  (#{candidate["url"]})" if candidate["url"]}" }
          return Outcome.new(ok: false, text: lines.join("\n"), data: { "apps" => apps })
        end

        Mcp::Platform.write_app_id(app["public_id"])
        success("Linked to #{app["name"]} (#{app["public_id"]}). Wrote ruby_native.app_id to #{Mcp::Platform::CONFIG_PATH}.", { "app_id" => app["public_id"], "name" => app["name"] })
      end
    end
  end
end
