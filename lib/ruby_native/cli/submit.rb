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

        # A questionnaire Apple or Google gives us no API for closes on the
        # person's word, and the word can ride along: --confirm=app_privacy.
        confirmations = @argv.select { |arg| arg.start_with?("--confirm=") }.map { |arg| arg.split("=", 2).last.to_s.strip }.reject(&:empty?)
        platforms = platforms!(app_id)

        # Play has no submit of ours: the answer is the go-live list with the
        # promotion steps, and nothing to confirm. It prints first so the
        # App Store question is the last thing on screen.
        android = (self.class.preview(app_id, platform: "android", confirmations: confirmations) if platforms.include?("android"))
        return finish(android) unless platforms.include?("ios")

        if android
          puts "Android:\n#{android.text}\n\niOS:"
        end
        ios = submit_ios(app_id, confirmations)
        puts ios.text
        exit 1 unless ios.ok && (android.nil? || android.ok)
      end

      def submit_ios(app_id, confirmations)
        preview = self.class.preview(app_id, confirmations: confirmations)
        return preview unless preview.ok

        puts preview.text
        puts ""

        unless @argv.include?("--yes")
          print "Submit for review? Type yes to continue: "
          answer = $stdin.gets.to_s.strip.downcase
          return Outcome.new(ok: false, text: "Not submitted.", data: {}) unless answer == "yes"
        end

        self.class.submit(app_id, preview.data["confirmation_token"])
      end

      def self.preview(app_id, platform: "ios", confirmations: [])
        body = {}
        body[:platform] = "android" if platform == "android"
        body[:confirm] = confirmations if confirmations.any?
        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/submission", body.empty? ? nil : body)
        return failure(result) unless result.ok?

        text = result.value["summary"].to_s
        blockers = result.value["blocked_by"]
        if platform == "android" && blockers.is_a?(Array) && blockers.any?
          text += "\n\n" + Status.blocker_lines(blockers).join("\n")
        end
        success(text, result.value)
      end

      def self.submit(app_id, confirmation_token)
        return Outcome.new(ok: false, text: "No confirmation token. Preview the submission first.", data: {}) if confirmation_token.to_s.empty?

        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/submission", { confirmation_token: confirmation_token })
        return failure(result) unless result.ok?

        success(result.value["note"].to_s, result.value)
      end

      def self.withdraw(app_id, platform: "ios")
        result = Mcp::Platform.request(Net::HTTP::Delete, "/api/v1/apps/#{app_id}/submission#{"?platform=android" if platform == "android"}")
        return failure(result) unless result.ok?

        success(result.value["note"].to_s, result.value)
      end
    end

    class Withdraw < Command
      def run
        ensure_authenticated!
        app_id = app_id!
        # Play has no review queue to leave, so only --android asks it.
        platforms = @argv.include?("--android") ? [ "android" ] : [ "ios" ]
        finish_each(platforms) { |platform| Submit.withdraw(app_id, platform: platform) }
      end
    end
  end
end
