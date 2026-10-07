require "ruby_native/cli/command"

module RubyNative
  class CLI
    # Store screenshots, captured by rubynative.com against the deployed site.
    # Each store has its own pages; the key, one per app, is only for pages
    # behind a sign-in. A capture is a job to follow. They reach the store
    # with the listing: `listing publish`, or the dashboard.
    class Screenshots < Command
      def run
        ensure_authenticated!
        app_id = app_id!

        case positional.first
        when "setup"
          paths = flag("paths").to_s.split(",").map(&:strip).reject(&:empty?)
          finish(self.class.setup(app_id, paths: paths, platforms: (platforms!(app_id) if paths.any?),
            sign_in: @argv.include?("--sign-in"), rotate_key: @argv.include?("--rotate-key")))
        when "capture"
          finish_each(platforms!(app_id)) { |platform| self.class.capture(app_id, platform: platform) }
        when "list", nil
          finish(self.class.list(app_id))
        else
          puts "Unknown screenshots command #{positional.first.inspect}. Use `setup`, `capture`, or `list`."
          exit 1
        end
      end

      # Sets each store's pages when given (no platforms sets both). The key is
      # only for pages behind a sign-in: generated with sign_in when there is
      # none, or replaced with rotate_key. It comes back once, with where to put it.
      def self.setup(app_id, paths: [], platforms: nil, sign_in: false, rotate_key: false)
        current = Mcp::Platform.get("/api/v1/apps/#{app_id}/screenshots")
        return failure(current) unless current.ok?

        lines = []
        data = current.value.dup
        if rotate_key || (sign_in && !current.value["key_configured"])
          key = Mcp::Platform.post("/api/v1/apps/#{app_id}/screenshots/key")
          return failure(key) unless key.ok?

          data["screenshot_key"] = key.value["screenshot_key"]
          lines << (key.value["rotated"] ? "Rotated the screenshot key. The old one stopped working." : "Generated the screenshot key.")
          lines << ""
          lines << "  #{key.value["screenshot_key"]}"
          lines << ""
          lines << "Add it to the app's Rails credentials and read it in an initializer, then deploy:"
          lines << ""
          lines << "  # bin/rails credentials:edit"
          lines << "  ruby_native:"
          lines << "    screenshot_key: <the key above>"
          lines << ""
          lines << "  # config/initializers/ruby_native.rb"
          lines << "  RubyNative.configure { |c| c.screenshot_key = Rails.application.credentials.ruby_native.screenshot_key }"
          lines << ""
        elsif sign_in
          lines << "The screenshot key is already set. Pass --rotate-key to replace it."
        end

        if paths.any?
          (platforms || [ nil ]).each do |platform|
            updated = Mcp::Platform.patch("/api/v1/apps/#{app_id}/screenshots", platform ? { paths: paths, platform: platform } : { paths: paths })
            return failure(updated) unless updated.ok?

            data = updated.value.merge(data.slice("screenshot_key"))
          end
          stores = (platforms || %w[ios android]).map { |platform| PLATFORM_LABELS[platform] }.join(" and ")
          lines << "Pages to capture for #{stores}: #{paths.join(", ")}"
        elsif Array(current.value["paths"]).empty?
          lines << "No pages to capture yet. Run this again with --paths /,/inbox,/settings (3 to 10 pages)."
        end

        lines << "Then: `ruby_native screenshots capture`."
        success(lines.join("\n"), data)
      end

      def self.capture(app_id, platform: "ios")
        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/screenshots/capture", { platform: platform })
        return failure(result) unless result.ok?

        capture = result.value["capture"] || {}
        success("Capturing #{platform} screenshots (capture #{capture["id"]}). #{result.value["note"]}", result.value)
      end

      def self.list(app_id)
        result = Mcp::Platform.get("/api/v1/apps/#{app_id}/screenshots")
        return failure(result) unless result.ok?

        value = result.value
        lines = []
        lines << "Sign-in key: #{value["key_configured"] ? "set" : "not set (only pages behind a sign-in need one: `ruby_native screenshots setup --sign-in`)"}"
        pages = value["pages"] || { "ios" => value["paths"] }
        pages.each do |platform, paths|
          paths = Array(paths)
          lines << "#{PLATFORM_LABELS.fetch(platform, platform)} pages: #{paths.empty? ? "none yet" : paths.join(", ")}"
        end
        (value["captures"] || {}).each do |platform, capture|
          label = platform == "ios" ? "iOS" : "Android"
          if capture.nil?
            lines << "#{label}: no capture yet"
          else
            state = capture["in_progress"] ? "in progress" : capture["status"]
            lines << "#{label}: capture #{capture["id"]} #{state}, #{capture["screenshots"]} screenshots#{capture["upload_status"] ? ", #{capture["upload_status"].tr("_", " ")}" : ""}"
          end
        end
        lines << "Publish them to the stores from #{value["dashboard_url"]}." if value["dashboard_url"]
        success(lines.join("\n"), value)
      end
    end
  end
end
