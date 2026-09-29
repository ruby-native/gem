require "ruby_native/cli/command"

module RubyNative
  class CLI
    # The App Store Connect key. Only a person can mint it, in App Store
    # Connect; this is how they hand it over without opening the dashboard.
    # The file is read here and sent once; nothing reads it back, and the
    # MCP tool takes a path for the same reason, so an agent never holds the
    # key itself.
    class Apple < Command
      POLL_INTERVAL = 2
      MAX_WAIT = 90

      USAGE = "Usage: ruby_native apple key <path/to/AuthKey.p8> --key-id=KEY --issuer-id=ISSUER --team-id=TEAM".freeze

      def run
        ensure_authenticated!
        app_id = app_id!

        unless positional.first == "key" && positional[1] && flag("key-id") && flag("issuer-id") && flag("team-id")
          puts USAGE
          exit 1
        end

        finish(self.class.set_key(app_id, path: positional[1], key_id: flag("key-id"), issuer_id: flag("issuer-id"), team_id: flag("team-id")))
      end

      def self.set_key(app_id, path:, key_id:, issuer_id:, team_id:, wait: MAX_WAIT)
        return Outcome.new(ok: false, text: "No file at #{path}.", data: {}) unless File.file?(path)

        result = Mcp::Platform.patch("/api/v1/apps/#{app_id}/credentials",
          { team_id: team_id, asc_key_id: key_id, asc_issuer_id: issuer_id, asc_key: File.read(path).strip })
        return failure(result) unless result.ok?

        settle(app_id, wait: wait)
      end

      # Validation runs against Apple in the background. Wait for it here,
      # because "sent" is not the answer anybody wants; "Apple took it" is.
      def self.settle(app_id, wait:)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wait

        loop do
          result = Mcp::Platform.get("/api/v1/apps/#{app_id}/credentials")
          return failure(result) unless result.ok?

          state = result.value.is_a?(Hash) ? result.value : {}
          case state["state"]
          when "passed"
            return success("Key verified: a Team key with the Admin role, and your agreements are signed. Ruby Native can sign and ship this app.", state)
          when "failed"
            return Outcome.new(ok: false, text: "Apple rejected the key: #{state["error"]}", data: state)
          end

          if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            return success("Still checking the key with Apple. Read `ruby_native status` in a minute; it says when the key checks out.", state)
          end

          pause
        end
      end

      # Two seconds between reads, and none in a test.
      def self.pause
        sleep POLL_INTERVAL unless @sleepless
      end

      def self.stub_const_sleep
        @sleepless = true
        yield
      ensure
        @sleepless = false
      end
    end
  end
end
