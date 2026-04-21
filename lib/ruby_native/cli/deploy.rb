require "json"
require "net/http"
require "uri"
require "ruby_native/cli/credentials"
require "ruby_native/version"

module RubyNative
  class CLI
    class Deploy
      CONFIG_PATH = "config/ruby_native.yml"
      HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")
      POLL_INTERVAL = 5
      POLL_TIMEOUT = 600

      TokenExpiredError = Class.new(StandardError)

      def initialize(argv)
        @if_needed = argv.include?("--if-needed")
      end

      def run
        load_config!
        ensure_authenticated!
        app_id = resolve_app_id!

        if @if_needed && skip_build?(app_id)
          puts "Ruby Native v#{RubyNative::VERSION} already built. Skipping deploy."
          return
        end

        build = trigger_build(app_id)
        return if @if_needed

        poll_build_status(app_id, build)
      end

      private

      def ensure_authenticated!
        unless Credentials.token
          puts "Not logged in. Run `ruby_native login` first."
          exit 1
        end
      end

      def load_config!
        unless File.exist?(CONFIG_PATH)
          puts "config/ruby_native.yml not found. Run `rails generate ruby_native:install` first."
          exit 1
        end

        require "yaml"
        @config = YAML.load_file(CONFIG_PATH, symbolize_names: true) || {}
      end

      def resolve_app_id!
        app_id = @config.dig(:ruby_native, :app_id)
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

        latest_gem_version = latest["gem_version"]
        return false unless latest_gem_version

        Gem::Version.new(latest_gem_version) >= Gem::Version.new(RubyNative::VERSION)
      rescue ArgumentError
        false
      end

      def fetch_latest_build(app_id)
        uri = URI("#{HOST}/api/v1/apps/#{app_id}/builds/latest")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPNoContent
          nil
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
        req.body = JSON.generate(gem_version: RubyNative::VERSION)

        response = make_request(uri, req)

        case response
        when Net::HTTPUnauthorized
          raise TokenExpiredError
        when Net::HTTPCreated
          build = JSON.parse(response.body)
          puts "Build ##{build["number"]} (v#{build["version"]}) queued."
          build
        when Net::HTTPTooManyRequests
          puts "Build limit reached. Try again later."
          exit 1
        when Net::HTTPConflict
          data = JSON.parse(response.body)
          puts data["error"]
          exit 1
        when Net::HTTPUnprocessableEntity
          data = JSON.parse(response.body)
          puts "Cannot build: #{data["error"]}"
          exit 1
        when Net::HTTPNotFound
          puts "App not found. Remove ruby_native.app_id from config/ruby_native.yml and run `ruby_native deploy` again to re-link."
          exit 1
        else
          puts "Failed to trigger build: #{response.code} #{response.message}"
          exit 1
        end
      rescue TokenExpiredError
        puts "Token expired. Run `ruby_native login` again."
        exit 1
      end

      # --- Polling ---

      def poll_build_status(app_id, build)
        build_id = build["id"]
        last_status = build["status"]
        puts ""
        puts "Waiting for build to complete. Ctrl+C to exit (your build will continue)."
        print_status(last_status)

        started_at = Time.now

        loop do
          sleep POLL_INTERVAL

          if Time.now - started_at > POLL_TIMEOUT
            puts ""
            puts "Timed out waiting for build. Check the Ruby Native dashboard for status."
            exit 1
          end

          data = fetch_build_status(app_id, build_id)
          next unless data

          if data["status"] != last_status
            last_status = data["status"]
            print_status(last_status)
          end

          case last_status
          when "success", "ready"
            puts ""
            puts "Build succeeded!"
            puts "  Version: v#{data["version"]} (#{data["number"]})"
            puts "  Ruby Native: #{data["native_version"]}" if data["native_version"]
            puts ""
            puts "Your build is being submitted to TestFlight."
            break
          when "failure", "failed", "cancelled"
            puts ""
            puts "Build failed."
            puts "  Error: #{data["error_message"]}" if data["error_message"]
            exit 1
          end
        end
      rescue Interrupt
        puts ""
        puts ""
        puts "Stopped polling. Your build is still running."
        puts "Check the Ruby Native dashboard for status."
      end

      def fetch_build_status(app_id, build_id)
        uri = URI("#{HOST}/api/v1/apps/#{app_id}/builds/#{build_id}")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)

        case response
        when Net::HTTPSuccess
          JSON.parse(response.body)
        when Net::HTTPUnauthorized
          puts ""
          puts "Token expired. Run `ruby_native login` again."
          exit 1
        end
      end

      def print_status(status)
        labels = {
          "queued" => "Queued",
          "building" => "Building",
          "processing" => "Submitting to App Store Connect"
        }
        label = labels[status]
        puts "  #{label}..." if label
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
          JSON.parse(response.body)
        else
          puts "Failed to fetch apps: #{response.code}"
          nil
        end
      end

      def write_app_id_to_config(app_id)
        raw = File.read(CONFIG_PATH)

        if raw.match?(/^ruby_native:/)
          raw = raw.gsub(/^(ruby_native:\s*\n)/, "\\1  app_id: #{app_id}\n")
        else
          raw = raw.rstrip + "\n\nruby_native:\n  app_id: #{app_id}\n"
        end

        File.write(CONFIG_PATH, raw)

        require "yaml"
        @config = YAML.load_file(CONFIG_PATH, symbolize_names: true) || {}
      end

      # --- HTTP ---

      def make_request(uri, req)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(req)
      end
    end
  end
end
