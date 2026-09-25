require "ruby_native/cli/credentials"
require "ruby_native/cli/mcp/platform"

module RubyNative
  class CLI
    # Where the app is and what is in the way, straight from the same answer
    # the dashboard reads. The MCP `status` tool renders exactly this, so a
    # person at a terminal and an agent see one report.
    #
    # A blocker names who clears it. "human" is a hand-off: the CLI prints the
    # steps and stops, because the step is one only a person can take (pay,
    # create the app record, answer a questionnaire Apple gives us no API for).
    class Status
      def initialize(argv = [])
        @app_id = argv.find { |arg| !arg.start_with?("--") }
      end

      def run
        app_id = @app_id || Mcp::Platform.app_id
        if app_id.to_s.strip.empty?
          puts Mcp::Platform::NO_APP_ID
          exit 1
        end

        result = self.class.fetch(app_id)
        unless result.ok?
          puts self.class.failure_message(result, app_id)
          exit 1
        end

        puts self.class.report(result.value)
      end

      def self.fetch(app_id)
        Mcp::Platform.get("/api/v1/apps/#{app_id}")
      end

      def self.failure_message(result, app_id)
        return result.error unless result.not_found?

        "No app #{app_id.inspect} on this account. Check `ruby_native.app_id` in #{Mcp::Platform::CONFIG_PATH}, " \
          "or pass an app id."
      end

      # --- Rendering ---

      def self.report(status)
        status = status.is_a?(Hash) ? status : {}
        ios = status["ios"] || {}
        android = status["android"] || {}
        subscription = status["subscription"] || {}

        lines = []
        lines << "#{status["name"]} (#{status["public_id"]}) · #{status["url"]}"
        lines << "Dashboard: #{status["dashboard_url"]}" if status["dashboard_url"]
        lines << ""
        lines << "iOS: #{track_summary(ios, store: "the App Store")}"
        lines << "Android: #{track_summary(android, store: "Google Play")}"
        lines << "Subscription: #{subscription_summary(subscription)}"
        lines << ""
        lines.concat(next_lines(ios, "iOS"))
        lines << ""
        lines.concat(next_lines(android, "Android"))

        lines.join("\n")
      end

      def self.track_summary(track, store:)
        parts = [ track["setup"] ]
        build = track["latest_build"]
        parts << (build ? "build #{build["number"]} (#{build["version"]}) #{build["status"]}" : "no build yet")
        parts << (track["live"] ? "live on #{store}" : "not on #{store}")
        parts.compact.join(" · ")
      end

      def self.subscription_summary(subscription)
        return "past due, builds paused" if subscription["past_due"]
        return "none" unless subscription["active"]

        subscription["plan"] ? "#{subscription["plan"]}, active" : "active"
      end

      # One track at a time: the stores gate differently, and an app can be
      # live on one and unbuilt on the other.
      def self.next_lines(track, label)
        blockers = Array(track["blocked_by"])
        act = track["next"].to_s
        android = label == "Android"

        if blockers.empty?
          return [ case act
                   when "submit" then "#{label}: nothing is in the way of submitting for review. Run `bundle exec ruby_native submit`."
                   when "wait" then "#{label}: in App Store review. Nothing to do but wait; `ruby_native withdraw` takes it back out."
                   when "release" then "#{label}: approved. Release it from App Store Connect."
                   when "go_live" then "#{label}: everything Google Play needs is in place."
                   else "#{label}: nothing is in the way of a build. Run `bundle exec ruby_native deploy#{" --android" if android}`."
                   end ]
        end

        verb = case act
               when "submit" then "submitting"
               when "go_live" then "going live on Google Play"
               else "building"
               end
        [ "#{label}: before #{verb}, #{blockers.size} #{blockers.size == 1 ? "thing needs" : "things need"} doing:", "" ] +
          blocker_lines(blockers)
      end

      # The steps are the same copy the dashboard shows, so a person reading
      # them off a terminal and one reading them off the web are told the
      # same thing.
      def self.blocker_lines(blockers)
        blockers.each_with_index.flat_map do |blocker, index|
          who = blocker["who"] == "agent" ? "an agent can do this" : "a person does this"
          seen = blocker["verifiable"] ? "Ruby Native sees it clear" : "Ruby Native cannot see it, so it is marked done on the dashboard"

          lines = [ "#{index + 1}. #{blocker["id"]} (#{who}; #{seen})" ]
          lines << "   #{blocker["why"]}" if blocker["why"]
          lines << "   #{blocker["url"]}" if blocker["url"]
          Array(blocker["steps"]).each_with_index { |step, i| lines << "     #{i + 1}. #{step}" }
          lines << ""
          lines
        end
      end
    end
  end
end
