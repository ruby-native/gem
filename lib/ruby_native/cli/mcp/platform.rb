require "json"
require "net/http"
require "uri"
require "yaml"
require "ruby_native/cli/credentials"
require "ruby_native/cli/mcp/config_validator"

module RubyNative
  class CLI
    class Mcp
      # The read-only slice of the Ruby Native API the server needs, using the
      # token `ruby_native login` already stored.
      #
      # Nothing here raises. Every failure comes back as a Result the tools
      # turn into something a model can act on -- "run ruby_native login",
      # "this server does not serve that yet" -- because an agent that gets an
      # exception learns nothing it can fix, and a server that cannot be
      # reached is an answer rather than a crash.
      class Platform
        HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")
        CONFIG_PATH = "config/ruby_native.yml".freeze
        TIMEOUT = 10

        NOT_LOGGED_IN = "Not logged in to Ruby Native. Run `ruby_native login` on this machine, " \
                        "or set RUBY_NATIVE_TOKEN.".freeze
        NO_APP_ID = "No app is linked to this project. Run `ruby_native deploy` once to link it, which writes " \
                    "`ruby_native.app_id` into #{CONFIG_PATH}, or pass `app_id` to this tool.".freeze

        Result = Struct.new(:value, :error, :status, keyword_init: true) do
          def ok?
            error.nil?
          end

          def not_found?
            status == 404
          end
        end

        def self.get(path)
          token = Credentials.token
          return Result.new(error: NOT_LOGGED_IN) unless token

          uri = URI("#{HOST}#{path}")
          request = Net::HTTP::Get.new(uri)
          request["Authorization"] = "Token #{token}"

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
            open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
            http.request(request)
          end

          interpret(response)
        rescue StandardError => error
          # Timeouts, DNS, TLS, a proxy in the way: all the same answer.
          Result.new(error: "Could not reach #{HOST}: #{error.class}: #{error.message}")
        end

        # Whether the account can see this app at all, which is what tells a
        # 404 on a missing route apart from a 404 on a missing app.
        def self.app?(app_id)
          result = get("/api/v1/apps")
          return nil unless result.ok?

          Array(result.value).any? { |app| app["public_id"] == app_id }
        end

        # app_id lives in the file the validator reads, and that file can carry
        # ERB, so tags are stubbed out the same way before parsing. A file that
        # will not parse means no app_id, which reads as "link this app".
        def self.app_id(path = CONFIG_PATH)
          return nil unless File.exist?(path)

          source = File.read(path, encoding: "UTF-8")
            .gsub(ConfigValidator::ERB_TAG, ConfigValidator::ERB_SENTINEL)
          config = YAML.load(source, aliases: true)
          return nil unless config.is_a?(Hash)

          value = config.dig("ruby_native", "app_id")
          value&.to_s
        rescue Psych::SyntaxError, SystemCallError, ArgumentError
          nil
        end

        def self.interpret(response)
          case response
          when Net::HTTPSuccess
            body = body_of(response)
            Result.new(value: body.empty? ? nil : JSON.parse(body), status: response.code.to_i)
          when Net::HTTPUnauthorized
            Result.new(error: "#{HOST} rejected the stored token. Run `ruby_native login` again.", status: 401)
          when Net::HTTPNotFound
            Result.new(error: "#{HOST} returned 404.", status: 404)
          else
            Result.new(error: "#{HOST} returned #{response.code}#{api_error(response)}.", status: response.code.to_i)
          end
        rescue JSON::ParserError
          Result.new(error: "#{HOST} returned a response that is not JSON.", status: response.code.to_i)
        end

        # The API reports its own failures as {"error": "..."}, which says more
        # than the status code does.
        def self.api_error(response)
          message = JSON.parse(body_of(response))["error"]
          message ? ": #{message}" : ""
        rescue JSON::ParserError, TypeError
          ""
        end

        # A body that was never read raises instead of coming back empty, and a
        # request that failed part way is exactly when that happens. Reading
        # the status is still worth something, so this never lets the body
        # decide whether there is an answer at all.
        def self.body_of(response)
          response.body.to_s
        rescue IOError
          ""
        end
        private_class_method :interpret, :api_error, :body_of
      end
    end
  end
end
