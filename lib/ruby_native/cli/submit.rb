require "ruby_native/cli/command"

module RubyNative
  class CLI
    # Submitting for App Store review is two calls. The first returns exactly
    # what would go to Apple and a token that expires in minutes; the second
    # needs the token. Here the person reads the summary and answers; the MCP
    # tool shows the model the same summary and tells it to ask.
    class Submit < Command
      def run
        ensure_authenticated!
        app_id = app_id!

        preview = self.class.preview(app_id)
        return finish(preview) unless preview.ok

        puts preview.text
        puts ""

        unless @argv.include?("--yes")
          print "Submit for review? Type yes to continue: "
          answer = $stdin.gets.to_s.strip.downcase
          unless answer == "yes"
            puts "Not submitted."
            exit 1
          end
        end

        finish(self.class.submit(app_id, preview.data["confirmation_token"]))
      end

      def self.preview(app_id)
        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/submission")
        return failure(result) unless result.ok?

        success(result.value["summary"].to_s, result.value)
      end

      def self.submit(app_id, confirmation_token)
        return Outcome.new(ok: false, text: "No confirmation token. Preview the submission first.", data: {}) if confirmation_token.to_s.empty?

        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/submission", { confirmation_token: confirmation_token })
        return failure(result) unless result.ok?

        success(result.value["note"].to_s, result.value)
      end

      def self.withdraw(app_id)
        result = Mcp::Platform.request(Net::HTTP::Delete, "/api/v1/apps/#{app_id}/submission")
        return failure(result) unless result.ok?

        success(result.value["note"].to_s, result.value)
      end
    end

    class Withdraw < Command
      def run
        ensure_authenticated!
        finish(Submit.withdraw(app_id!))
      end
    end
  end
end
