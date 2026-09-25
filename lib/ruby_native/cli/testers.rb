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
            puts "Usage: ruby_native testers add <apple-id-email>"
            exit 1
          end
          finish(self.class.add(app_id, email))
        when "list", nil
          finish(self.class.list(app_id))
        else
          puts "Unknown testers command #{positional.first.inspect}. Use `add` or `list`."
          exit 1
        end
      end

      def self.list(app_id)
        result = Mcp::Platform.get("/api/v1/apps/#{app_id}/testers")
        return failure(result) unless result.ok?

        testers = Array(result.value["testers"])
        return success("No testers yet. Add one with `ruby_native testers add <email>`.", result.value) if testers.empty?

        width = testers.map { |tester| tester["email"].to_s.length }.max
        lines = testers.map do |tester|
          "#{tester["email"].to_s.ljust(width)}  #{tester["accepted"] ? "accepted" : "invited, not accepted"}"
        end
        success(lines.join("\n"), result.value)
      end

      def self.add(app_id, email)
        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/testers", { email: email })
        return failure(result) unless result.ok?

        success(result.value["message"].to_s, result.value)
      end
    end
  end
end
