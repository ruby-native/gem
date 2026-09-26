require "json"
require "net/http"
require "uri"
require "yaml"
require "ruby_native/cli/credentials"
require "ruby_native/cli/mcp/config_validator"

module RubyNative
  class CLI
    class Mcp
      # The slice of the Ruby Native API the CLI and the MCP server share,
      # using the token `ruby_native login` already stored.
      #
      # Nothing here raises. Every failure comes back as a Result the callers
      # turn into something a person or a model can act on -- "run ruby_native
      # login", "this app is blocked by these things" -- because an agent that
      # gets an exception learns nothing it can fix, and a server that cannot
      # be reached is an answer rather than a crash.
      class Platform
        HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")
        CONFIG_PATH = "config/ruby_native.yml".freeze
        TIMEOUT = 10
        # Icons and captures take longer than a status read.
        WRITE_TIMEOUT = 60

        NOT_LOGGED_IN = "Not logged in to Ruby Native. Run `ruby_native login` on this machine, " \
                        "or set RUBY_NATIVE_TOKEN.".freeze
        NO_APP_ID = "No app is linked to this project. Run `ruby_native deploy` once to link it, which writes " \
                    "`ruby_native.app_id` into #{CONFIG_PATH}, or pass `app_id` to this tool.".freeze

        # `body` is the parsed error response, when there was one: the API
        # explains a refusal with `blocked_by` (the blockers contract) or
        # `errors` (a validation failure), and both are worth more than the
        # status code.
        Result = Struct.new(:value, :error, :status, :body, keyword_init: true) do
          def ok?
            error.nil?
          end

          def not_found?
            status == 404
          end

          def blocked_by
            list = body.is_a?(Hash) ? body["blocked_by"] : nil
            list.is_a?(Array) ? list : []
          end

          def field_errors
            errors = body.is_a?(Hash) ? body["errors"] : nil
            errors.is_a?(Hash) ? errors : {}
          end
        end

        def self.get(path)
          request(Net::HTTP::Get, path)
        end

        def self.patch(path, json)
          request(Net::HTTP::Patch, path, json: json, timeout: WRITE_TIMEOUT)
        end

        def self.post(path, json = nil)
          request(Net::HTTP::Post, path, json: json, timeout: WRITE_TIMEOUT)
        end

        def self.put_file(path, field:, file:, content_type:)
          request(Net::HTTP::Put, path, timeout: WRITE_TIMEOUT) do |req|
            req.set_form([ [ field, File.open(file, "rb"), { filename: File.basename(file), content_type: content_type } ] ], "multipart/form-data")
          end
        end

        def self.request(klass, path, json: nil, timeout: TIMEOUT)
          token = Credentials.token
          return Result.new(error: NOT_LOGGED_IN) unless token

          uri = URI("#{HOST}#{path}")
          req = klass.new(uri)
          req["Authorization"] = "Token #{token}"
          if json
            req["Content-Type"] = "application/json"
            req.body = JSON.generate(json)
          end
          yield req if block_given?

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
            open_timeout: TIMEOUT, read_timeout: timeout) do |http|
            http.request(req)
          end

          interpret(response)
        rescue StandardError => error
          # Timeouts, DNS, TLS, a proxy in the way: all the same answer.
          Result.new(error: "Could not reach #{HOST}: #{error.class}: #{error.message}")
        end

        # app_id lives in the file the validator reads, and that file can carry
        # ERB, so tags are stubbed out the same way before parsing. A file that
        # will not parse means no app_id, which reads as "link this app".
        # Adds `ruby_native: app_id:` to the config, or fills it in under an
        # existing `ruby_native:` key, and leaves everything else as written.
        def self.write_app_id(app_id, path = CONFIG_PATH)
          raw = File.exist?(path) ? File.read(path) : ""
          raw = if raw.match?(/^ruby_native:\s*\n(\s+app_id:.*\n)?/)
            raw.sub(/^(ruby_native:\s*\n)(\s+app_id:.*\n)?/, "\\1  app_id: #{app_id}\n")
          else
            raw.rstrip + "\n\nruby_native:\n  app_id: #{app_id}\n"
          end
          File.write(path, raw)
        end

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
            parsed = parse(body_of(response))
            message = parsed.is_a?(Hash) && parsed["error"] ? parsed["error"] : "#{HOST} returned #{response.code}."
            Result.new(error: message, status: response.code.to_i, body: parsed)
          end
        rescue JSON::ParserError
          Result.new(error: "#{HOST} returned a response that is not JSON.", status: response.code.to_i)
        end

        def self.parse(body)
          JSON.parse(body)
        rescue JSON::ParserError, TypeError
          nil
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
        private_class_method :interpret, :parse, :body_of
      end
    end
  end
end
