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
        @app_id = argv.find { |arg| arg.start_with?("--app=") }&.split("=", 2)&.last || argv.find { |arg| !arg.start_with?("--") }
      end

      # What the layout has to carry before the app looks like one. Read as
      # substrings across every layout, so a helper split over lines or moved
      # into a partial the layout renders is missed: the report says "missing"
      # and the person can see it is not. Wrong the safe way round.
      LAYOUT_GLOB = "app/views/layouts/**/*.html.erb".freeze
      MARKERS = {
        "stylesheet_link_tag :ruby_native" => "the Ruby Native stylesheet",
        "viewport-fit=cover" => "viewport-fit=cover",
        "native_tabs_tag" => "native_tabs_tag",
        "native_identity_tag" => "native_identity_tag"
      }.freeze

      def run
        app_id = @app_id || Mcp::Platform.app_id
        if app_id.to_s.strip.empty? || Credentials.token.nil?
          puts self.class.local_report
          return
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

      # --- Before an app is linked ---

      # Everything `status` can know without the API: the file the generator
      # writes, the four things the first native pass puts in the layout, and
      # whether login and link have happened. The next step follows from which
      # of those is missing first.
      def self.local
        layouts = Dir.glob(LAYOUT_GLOB).sort.map { |path| File.read(path) }.join("\n")

        {
          "local" => true,
          "gem_version" => RubyNative::VERSION,
          "config" => File.exist?(Mcp::Platform::CONFIG_PATH),
          "layout" => MARKERS.keys.to_h { |marker| [ marker, layouts.include?(marker) ] },
          "app_id" => Mcp::Platform.app_id,
          "logged_in" => !Credentials.token.nil?
        }
      end

      def self.local_report(local = self.local)
        missing = local["layout"].reject { |_, present| present }.keys.map { |marker| MARKERS[marker] }

        lines = [ "Ruby Native #{local["gem_version"]}, before an app is linked.", "" ]
        lines << "  #{Mcp::Platform::CONFIG_PATH}: #{local["config"] ? "present" : "missing"}"
        lines << "  Layout: #{missing.empty? ? "has the first native pass" : "missing #{missing.join(", ")}"}"
        lines << "  Login: #{local["logged_in"] ? "stored" : "none"}"
        lines << "  Linked app: #{local["app_id"] || "none"}"
        lines << ""
        lines << "Next: #{local_next(local, missing)}"
        lines.join("\n")
      end

      def self.local_next(local, missing)
        if !local["config"]
          "run `bin/rails generate ruby_native:install`."
        elsif missing.any?
          "the first native pass, the seven changes in the `ship` prompt (`ruby_native ship` prints it). " \
            "Then `bundle exec ruby_native preview` to see it on a phone."
        elsif !local["logged_in"]
          "create the app at #{Mcp::Platform::HOST}/apps/new (a name, the site's URL, and an account if you have none), " \
            "then `ruby_native login` and `ruby_native link`."
        else
          "run `ruby_native link` to pick the app on your account."
        end
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
