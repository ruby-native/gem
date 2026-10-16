require "json"
require "net/http"
require "uri"
require "openssl"
require "ruby_native/cli/check"
require "ruby_native/cli/credentials"
require "ruby_native/cli/mcp/platform"
require "ruby_native/cli/status"
require "ruby_native/version"

module RubyNative
  class CLI
    class Deploy
      CONFIG_PATH = "config/ruby_native.yml"
      HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")
      POLL_INTERVAL = 5
      POLL_TIMEOUT = 600
      PLATFORMS = %w[ios android all].freeze
      # Consecutive failures tolerated mid-poll; one blip must not kill a
      # deploy whose build is succeeding server-side.
      MAX_POLL_FAILURES = 3

      TokenExpiredError = Class.new(StandardError)
      ConnectionError = Class.new(StandardError)

      NETWORK_ERRORS = [
        SocketError,
        Errno::ECONNREFUSED,
        Errno::ECONNRESET,
        Net::OpenTimeout,
        Net::ReadTimeout,
        OpenSSL::SSL::SSLError
      ].freeze

      def initialize(argv)
        @if_needed = argv.include?("--if-needed")
        @skip_check = argv.include?("--skip-check")
        @platform = parse_platform(argv)
        @app_flag = argv.find { |arg| arg.start_with?("--app=") }&.split("=", 2)&.last
        @version = argv.find { |arg| arg.start_with?("--version=") }&.split("=", 2)&.last
      end

      def run
        load_config!
        ensure_authenticated!
        app_id = resolve_app_id!

        if @if_needed && skip_build?(app_id)
          puts "Ruby Native v#{RubyNative::VERSION} already built. Skipping deploy."
          return
        end

        unless @skip_check
          check_signals!
          warn_scan_without_camera(app_id)
        end

        build = trigger_build(app_id)
        return if @if_needed

        # `builds` is present when one deploy started more than one; an older
        # server omits it and the primary build is the whole story.
        poll_build_status(app_id, build, Array(build["builds"]).drop(1))
      rescue TokenExpiredError
        abort_token_expired!
      rescue ConnectionError => error
        puts error.message
        puts "Check your internet connection and run `ruby_native deploy` again."
        exit 1
      end

      private

      # A broken signal is invisible until someone opens the build, so it is
      # worth a second here rather than a TestFlight round trip. Skipped
      # silently when herb is missing: this is a courtesy, not a dependency the
      # gem gets to impose on a deploy.
      def check_signals!
        offenses = Check.signal_offenses
        return if offenses.nil?

        errors = offenses.select { |offense| offense.severity == :error }
        return if errors.empty?

        puts "Found #{errors.size} signal #{errors.size == 1 ? "problem" : "problems"} in your views:"
        errors.first(10).each { |error| puts "  #{error.file}:#{error.line}  #{error.message}" }
        puts "  ...and #{errors.size - 10} more." if errors.size > 10
        puts
        puts "These will not work in the build. Fix them, or deploy anyway with --skip-check."
        exit 1
      end

      # A warning, not a stop: the build is fine, one button in it isn't.
      def warn_scan_without_camera(app_id)
        file, line = Permissions.scan_without_camera(app_id)
        return unless file

        puts "Heads up: #{Permissions.scan_without_camera_message(file, line)}"
        puts
      rescue StandardError
        nil
      end

      def ensure_authenticated!
        return if Credentials.token

        if ENV.key?("RUBY_NATIVE_TOKEN")
          puts "RUBY_NATIVE_TOKEN is set but empty, so there is no usable token."
          puts "Check the CI secret it references, or unset it and run `ruby_native login`."
        else
          puts "Not logged in. Run `ruby_native login` first."
        end
        exit 1
      end

      def abort_token_expired!
        if Credentials.env_token
          puts "The server rejected your token."
          puts "RUBY_NATIVE_TOKEN is set and overrides `ruby_native login`, so update"
          puts "that environment variable with a fresh token."
        else
          puts "Token expired. Run `ruby_native login` again."
        end
        exit 1
      end

      def load_config!
        unless File.exist?(CONFIG_PATH)
          puts "config/ruby_native.yml not found. Run `rails generate ruby_native:install` first."
          exit 1
        end

        @config = read_config
      end

      def read_config
        require "yaml"
        YAML.load(rendered_config, filename: CONFIG_PATH, symbolize_names: true, aliases: true) || {}
      rescue Psych::SyntaxError => error
        puts "config/ruby_native.yml has a YAML syntax error:"
        puts "  #{error.message}"
        puts "Fix it and run `ruby_native deploy` again."
        exit 1
      end

      # Rails renders this file as ERB before parsing, so the CLI must too or
      # any <% %> tag breaks deploys while the app works fine.
      def rendered_config
        require "erb"
        ERB.new(File.read(CONFIG_PATH), trim_mode: "-").result(erb_stub_binding)
      rescue StandardError, SyntaxError
        # A template only Rails can render still deploys; the CLI needs just app_id.
        File.read(CONFIG_PATH)
      end

      # View helpers like image_url do not exist outside Rails; render them to
      # "" rather than failing the deploy over values the CLI never reads.
      def erb_stub_binding
        stub = Object.new
        def stub.method_missing(*, **) = ""
        def stub.respond_to_missing?(*) = true
        stub.instance_eval { binding }
      end

      def resolve_app_id!
        app_id = (@app_flag unless @app_flag.to_s.strip.empty?) || @config.dig(:ruby_native, :app_id)
        app_id = link_app unless app_id
        unless app_id
          puts "No app selected. Run `ruby_native deploy` again."
          exit 1
        end
        app_id
      end

      # --- Version check ---

      def skip_build?(app_id)
        latest = fetch_latest_build(app_id)
        return false unless latest

        return skip_all?(latest) if @platform == "all"

        current?(latest["gem_version"])
      rescue ArgumentError
        false
      end

      # Skip only when every platform that could build is already on this gem
      # version. A track that is set up but has never built is exactly the case
      # that must not skip, which is why the server reports `deployable`
      # separately from whether a build exists.
      def skip_all?(latest)
        deployable = latest.select { |_platform, state| state.is_a?(Hash) && state["deployable"] }
        return false if deployable.empty?

        deployable.all? { |_platform, state| current?(state["gem_version"]) }
      end

      def current?(gem_version)
        return false unless gem_version

        Gem::Version.new(gem_version) >= Gem::Version.new(RubyNative::VERSION)
      end

      def fetch_latest_build(app_id)
        # Platform-scoped, or --android --if-needed compares against the
        # latest iOS build and skips a build Android never got.
        uri = URI("#{HOST}/api/v1/apps/#{app_id}/builds/latest?platform=#{@platform}")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)

        case response
        # Before HTTPSuccess, its superclass: a 204 has no body to parse, and
        # matching Success first crashed --if-needed before an app's first
        # successful build.
        when Net::HTTPNoContent
          nil
        when Net::HTTPSuccess
          parse_json(response)
        when Net::HTTPUnauthorized
          raise TokenExpiredError
        else
          nil
        end
      end

      # --- Build ---

      def trigger_build(app_id)
        puts "Triggering build..."

        uri = URI("#{HOST}/api/v1/apps/#{app_id}/builds")
        req = Net::HTTP::Post.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(build_payload)

        response = make_request(uri, req)

        case response
        when Net::HTTPUnauthorized
          raise TokenExpiredError
        when Net::HTTPCreated
          build = parse_json(response)
          unless build
            puts "The build was queued, but its details could not be read."
            puts "Check the Ruby Native dashboard for progress: #{HOST}/dashboard"
            exit 0
          end
          puts "Build ##{build["number"]} (v#{build["version"]}) queued."
          print_notice(build)
          build
        when Net::HTTPTooManyRequests
          puts "Build limit reached. Try again later."
          exit 1
        when Net::HTTPConflict
          data = parse_json(response)
          puts data&.dig("error") || "A build is already in progress. Check the Ruby Native dashboard."
          exit 1
        when Net::HTTPUnprocessableEntity
          data = parse_json(response)
          puts "Cannot build: #{data&.dig("error") || "the server rejected the request (422)."}"
          print_blockers(data)
          exit 1
        when Net::HTTPNotFound
          puts "The app linked in config/ruby_native.yml was not found on your account."
          puts "It may have been archived. Check your apps first: #{HOST}/dashboard"
          puts "If you meant to link a different app, remove `app_id` from"
          puts "config/ruby_native.yml and run `ruby_native deploy` again."
          exit 1
        else
          puts "Failed to trigger build: #{response.code} #{response.message}"
          exit 1
        end
      end

      # --- Polling ---

      # Polls every build this deploy started, not just the first. With both
      # platforms dispatched at once, watching only one meant a failed Android
      # build exited 0 and left CI green over a broken release.
      def poll_build_status(app_id, build, others = [])
        states = ([build] + Array(others)).compact.uniq { |candidate| candidate["id"] }.map do |candidate|
          { id: candidate["id"], platform: candidate["platform"], status: candidate["status"], not_found: 0, error: nil, result: nil }
        end
        many = states.size > 1

        puts ""
        puts "Waiting for #{many ? "builds" : "build"} to complete. Ctrl+C to exit (your #{many ? "builds" : "build"} will continue)."
        states.each { |state| print_status(state[:status], label_for(state, many)) }

        started_at = Time.now
        connection_failures = 0

        loop do
          sleep POLL_INTERVAL

          if Time.now - started_at > POLL_TIMEOUT
            puts ""
            puts "Timed out waiting for build. Check the Ruby Native dashboard for status."
            exit 1
          end

          connection_error = nil
          reached = 0

          states.reject { |state| state[:result] }.each do |state|
            begin
              api_state, payload = fetch_build_status(app_id, state[:id])
              reached += 1
            rescue ConnectionError => error
              connection_error = error
              next
            end

            advance_build(state, api_state, payload, many)
          end

          # Only a tick where nothing was reachable counts against the budget,
          # so one platform answering keeps the deploy alive.
          if reached.zero?
            connection_failures += 1
            next if connection_failures < MAX_POLL_FAILURES

            puts ""
            puts connection_error.message
            puts "Your build is most likely still running server-side. Check the"
            puts "Ruby Native dashboard for the result: #{HOST}/dashboard"
            exit 1
          end

          connection_failures = 0
          break if states.all? { |state| state[:result] }
        end

        exit 1 if states.any? { |state| state[:result] == :failed }
      rescue Interrupt
        puts ""
        puts ""
        puts "Stopped polling. Your build is still running."
        puts "Check the Ruby Native dashboard for status."
      end

      def advance_build(state, api_state, payload, many)
        label = label_for(state, many)

        case api_state
        when :not_found
          state[:not_found] += 1
          return if state[:not_found] < MAX_POLL_FAILURES

          puts ""
          puts "#{label}The server can no longer find this build (404). The app or build"
          puts "may have been deleted or archived. Check the Ruby Native"
          puts "dashboard: #{HOST}/dashboard"
          state[:result] = :failed
          return
        when :error
          # The build keeps running server-side through a 500, so keep polling.
          if payload != state[:error]
            state[:error] = payload
            puts ""
            puts "#{label}#{URI(HOST).host} returned #{payload} while checking the build. Still trying..."
          end
          return
        end

        state[:not_found] = 0
        data = payload
        print_notice(data)

        if data["status"] != state[:status]
          state[:status] = data["status"]
          print_status(state[:status], label)
        end

        case state[:status]
        when "success", "ready"
          puts ""
          puts "#{label}Build succeeded!"
          puts "  Version: v#{data["version"]} (#{data["number"]})"
          puts "  Ruby Native: #{data["native_version"]}" if data["native_version"]
          puts ""
          puts success_destination_message(data)
          state[:result] = :succeeded
        when "failure", "failed", "cancelled"
          puts ""
          puts "#{label}Build failed."
          puts "  Error: #{data["error_message"]}" if data["error_message"]
          state[:result] = :failed
        end
      end

      # Platform names only appear when there is more than one build to tell
      # apart, so single-platform output is unchanged.
      def label_for(state, many)
        return "" unless many

        case state[:platform]
        when "ios" then "iOS: "
        when "android" then "Android: "
        else ""
        end
      end

      # Returns [:ok, data], [:not_found, nil], or [:error, description].
      # Raises ConnectionError when the request never completed.
      def fetch_build_status(app_id, build_id)
        uri = URI("#{HOST}/api/v1/apps/#{app_id}/builds/#{build_id}")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)

        case response
        when Net::HTTPSuccess
          begin
            [:ok, JSON.parse(response.body)]
          rescue JSON::ParserError
            [:error, "an unreadable response (HTTP #{response.code})"]
          end
        when Net::HTTPUnauthorized
          puts ""
          abort_token_expired!
        when Net::HTTPNotFound
          [:not_found, nil]
        else
          [:error, "HTTP #{response.code}"]
        end
      end

      def print_status(status, prefix = "")
        label = status_labels[status]
        puts "  #{prefix}#{label}..." if label
      end

      # Server-provided warnings (a lapsed payment, say) reach customers with
      # no gem release. Deduped, since every status poll repeats the string.
      # A refusal names what is in the way and who clears it, the same list the
      # dashboard shows. An older server sends only the sentence.
      def print_blockers(data)
        blockers = data.is_a?(Hash) ? data["blocked_by"] : nil
        return unless blockers.is_a?(Array) && blockers.any?

        puts ""
        puts Status.blocker_lines(blockers)
      end

      def print_notice(data)
        notice = data["notice"]
        return unless notice.is_a?(String) && !notice.strip.empty?
        return if notice == @printed_notice

        @printed_notice = notice
        puts "Notice: #{notice}"
      end

      def status_labels
        if android?
          {
            "queued" => "Queued",
            "building" => "Building Android AAB",
            "processing" => "Uploading to Play Internal Testing"
          }
        else
          {
            "queued" => "Queued",
            "building" => "Building",
            "processing" => "Submitting to App Store Connect"
          }
        end
      end

      def success_destination_message(data)
        platform = data["platform"] || requested_platform
        case platform
        when "android"
          "Your build is being uploaded to Play Internal Testing."
        else
          "Your build is being submitted to TestFlight."
        end
      end

      # Every configured platform by default: "deploy my app" means the app, not
      # whichever half was written first. The server decides what is actually
      # ready, so an iOS-only app still just builds iOS.
      def parse_platform(argv)
        return "android" if argv.include?("--android")
        return "ios" if argv.include?("--ios")

        flag = argv.find { |a| a.start_with?("--platform=") }
        return "all" unless flag

        value = flag.split("=", 2).last
        unless PLATFORMS.include?(value)
          puts "Unknown platform #{value.inspect}. Use --platform=ios, --platform=android, or --platform=all."
          exit 1
        end
        value
      end

      def requested_platform
        @platform
      end

      def android?
        @platform == "android"
      end

      def build_payload
        payload = { gem_version: RubyNative::VERSION }
        payload[:platform] = @platform unless @platform == "ios"
        payload[:version] = @version if @version && !@version.empty?
        payload
      end

      # --- App linking ---

      def link_app
        apps = fetch_apps
        return unless apps

        if apps.empty?
          puts "No apps found on your account."
          return
        end

        app = if apps.length == 1
          puts "Using app: #{apps[0]["name"]}"
          apps[0]
        else
          puts "Which app?"
          apps.each_with_index do |a, i|
            puts "  #{i + 1}. #{a["name"]}"
          end
          print "> "
          choice = ($stdin.gets&.strip || "").to_i
          unless choice.between?(1, apps.length)
            puts "Invalid choice."
            return
          end
          apps[choice - 1]
        end

        app_id = app["public_id"]
        write_app_id_to_config(app_id)
        app_id
      end

      def fetch_apps
        uri = URI("#{HOST}/api/v1/apps")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)

        case response
        when Net::HTTPUnauthorized
          raise TokenExpiredError
        when Net::HTTPSuccess
          parse_json(response)
        else
          puts "Failed to fetch apps: #{response.code}"
          nil
        end
      end

      def write_app_id_to_config(app_id)
        Mcp::Platform.write_app_id(app_id, CONFIG_PATH)
        @config = read_config
      end

      # --- HTTP ---

      def make_request(uri, req)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(req)
      rescue *NETWORK_ERRORS => error
        raise ConnectionError, "Could not connect to #{uri.host} (#{error.class}: #{error.message})."
      end

      # Proxies and WAFs answer with HTML error pages; nil instead of a
      # JSON::ParserError backtrace.
      def parse_json(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        puts "Unexpected response from #{URI(HOST).host}: HTTP #{response.code} with a body that is not JSON."
        nil
      end
    end
  end
end
