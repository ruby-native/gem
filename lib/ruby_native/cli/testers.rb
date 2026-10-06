require "ruby_native/cli/command"

module RubyNative
  class CLI
    # Internal TestFlight testers. Adding one reaches App Store Connect, through
    # rubynative.com, which holds the key.
    class Testers < Command
      def run
        ensure_authenticated!
        app_id = app_id!

        case positional.first
        when "add"
          email = positional[1]
          unless email
            puts "Usage: ruby_native testers add <email> [--ios|--android]"
            exit 1
          end
          finish_each(platforms!(app_id)) { |platform| self.class.add(app_id, email, platform: platform) }
        when "list", nil
          finish_each(platforms!(app_id)) { |platform| self.class.list(app_id, platform: platform) }
        else
          puts "Unknown testers command #{positional.first.inspect}. Use `add` or `list`."
          exit 1
        end
      end

      # Play keeps its tester list in the Console, so `--android` comes back
      # as the hand-off in the blockers shape rather than a list.
      def self.list(app_id, platform: "ios")
        result = Mcp::Platform.get("/api/v1/apps/#{app_id}/testers#{"?platform=android" if platform == "android"}")
        return failure(result) unless result.ok?

        testers = Array(result.value["testers"])
        return success("No testers yet. Add one with `ruby_native testers add <email>`.", result.value) if testers.empty?

        width = testers.map { |tester| tester["email"].to_s.length }.max
        lines = testers.map do |tester|
          "#{tester["email"].to_s.ljust(width)}  #{tester["accepted"] ? "accepted" : "invited, not accepted"}"
        end
        success(lines.join("\n"), result.value)
      end

      def self.add(app_id, email, platform: "ios")
        body = { email: email }
        body[:platform] = "android" if platform == "android"
        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/testers", body)
        return failure(result) unless result.ok?

        success(result.value["message"].to_s, result.value)
      end
    end
  end
end
