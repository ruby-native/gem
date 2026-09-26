require "ruby_native/cli/credentials"
require "ruby_native/cli/mcp/platform"
require "ruby_native/cli/status"

module RubyNative
  class CLI
    # What every command that talks to rubynative.com about one app shares:
    # finding the app, being logged in, and turning a refusal into something a
    # person can act on. The MCP server calls the same `perform` methods, so a
    # verb is a CLI command first and a tool second, and both say one thing.
    class Command
      Outcome = Struct.new(:ok, :text, :data, keyword_init: true)

      def initialize(argv = [])
        @argv = argv
      end

      private

      def app_id!
        flag = @argv.find { |arg| arg.start_with?("--app=") }
        app_id = flag ? flag.split("=", 2).last : Mcp::Platform.app_id
        return app_id unless app_id.to_s.strip.empty?

        puts Mcp::Platform::NO_APP_ID
        exit 1
      end

      def ensure_authenticated!
        return if Credentials.token

        puts Mcp::Platform::NOT_LOGGED_IN
        exit 1
      end

      def finish(outcome)
        puts outcome.text
        exit 1 unless outcome.ok
      end

      def positional
        @argv.reject { |arg| arg.start_with?("--") }
      end

      def flag(name)
        value = @argv.find { |arg| arg.start_with?("--#{name}=") }
        value&.split("=", 2)&.last
      end

      def self.failure(result)
        lines = [ result.error ]
        result.field_errors.each do |field, messages|
          Array(messages).each do |message|
            next if result.error.to_s.downcase.include?(message.to_s.downcase)

            lines << "  #{field} #{message}"
          end
        end
        if result.blocked_by.any?
          lines << ""
          lines.concat(Status.blocker_lines(result.blocked_by))
        end
        Outcome.new(ok: false, text: lines.join("\n").strip, data: { "error" => result.error, "blocked_by" => result.blocked_by, "errors" => result.field_errors })
      end

      def self.success(text, data)
        Outcome.new(ok: true, text: text, data: data)
      end
    end
  end
end
