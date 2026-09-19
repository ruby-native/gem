require "json"
require "net/http"
require "uri"
require "yaml"
require "ruby_native/cli/credentials"
require "ruby_native/signals"
require "ruby_native/version"

module RubyNative
  class CLI
    # Static validation of a Rails app's views against the signal vocabulary.
    #
    # Signals fail silently by design: a shell that does not understand one
    # ignores it. That is right for progressive enhancement and miserable for
    # debugging, so this moves the diagnostics the bridge already runs per page
    # visit to a whole-app pass that can fail CI before a build goes out.
    class Check
      CONFIG_PATH = "config/ruby_native.yml"
      HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")
      DEFAULT_PATHS = ["app/views"].freeze
      PLATFORMS = %w[ios android].freeze

      Offense = Struct.new(:file, :line, :severity, :message, keyword_init: true)

      # The same checks `run` reports, for `deploy` to run as a preflight.
      # Returns nil when herb is missing rather than failing: a deploy must not
      # start depending on a gem the app never asked for.
      def self.signal_offenses(paths: DEFAULT_PATHS)
        return nil unless herb_available?

        check = new([], paths: paths)

        template_files(paths: paths).flat_map { |file| check.send(:check_file, file) }
      end

      # The templates a run covers. Public so a caller can count them without
      # running the checks, and so there is one definition of what gets scanned.
      def self.template_files(paths: DEFAULT_PATHS)
        paths.flat_map { |path| Dir.glob(File.join(path, "**", "*.html.erb")) }.sort
      end

      # The report `run` prints, as lines, so another front end renders
      # offenses the way the CLI does instead of inventing a second format.
      def self.report_lines(files, offenses)
        lines = []

        offenses.group_by(&:file).sort.each do |file, file_offenses|
          lines << file
          file_offenses.sort_by(&:line).each do |offense|
            location = "#{offense.line}:".ljust(5)
            marker = offense.severity.to_s.ljust(8)
            lines << "  #{location}#{marker}#{offense.message}"
          end
          lines << ""
        end

        lines << summary_line(files, offenses)
      end

      def self.summary_line(files, offenses)
        errors, warnings = offenses.partition { |offense| offense.severity == :error }
        summary = "Checked #{files.size} #{files.size == 1 ? "template" : "templates"}"

        if offenses.empty?
          "#{summary}. No problems found."
        else
          "#{summary}: #{errors.size} #{errors.size == 1 ? "error" : "errors"}, " \
            "#{warnings.size} #{warnings.size == 1 ? "warning" : "warnings"}."
        end
      end

      def self.herb_available?
        require "herb"
        require "ruby_native/cli/check/signal_collector"
        true
      rescue LoadError
        false
      end

      def initialize(argv, paths: nil)
        @deployed = argv.include?("--deployed")
        @paths = paths || parse_paths(argv)
      end

      def run
        require_herb!

        files = template_files
        if files.empty?
          puts "No .html.erb templates found in #{@paths.join(", ")}."
          return
        end

        offenses = files.flat_map { |file| check_file(file) }
        offenses += deployed_offenses(files) if @deployed

        report(files, offenses)
        exit 1 if offenses.any? { |offense| offense.severity == :error }
      end

      private

      # --- Loading ---

      def require_herb!
        return if self.class.herb_available?

        puts "`ruby_native check` needs the herb gem, which parses HTML and ERB together."
        puts ""
        puts "Add it to your Gemfile:"
        puts "  gem \"herb\""
        puts ""
        puts "Rails 8.2 and later already ship it as a dependency of Action View."
        exit 1
      end

      def template_files
        self.class.template_files(paths: @paths)
      end

      # --- Per-file checks ---

      # Herb's parser tolerates markup its compiler rejects, so every template
      # gets scanned whether or not it would build under Rails 8.2. Whether
      # their ERB is Herb-clean is their upgrade to make, and `herb lint` is
      # the tool for it.
      def check_file(file)
        signal_offenses(file, File.read(file, encoding: "UTF-8"))
      rescue ArgumentError => error
        [Offense.new(file: file, line: 1, severity: :error, message: "Could not read the file: #{error.message}")]
      end

      def signal_offenses(file, source)
        result = Herb.parse(source)
        collector = SignalCollector.new
        result.value.accept(collector)

        offenses = []

        collector.signals.each do |name, lines|
          unless RubyNative::Signals.known?(name)
            suggestion = RubyNative::Signals.nearest(name)
            message = "Unknown signal `#{name}`."
            message += " Did you mean `#{suggestion}`?" if suggestion
            offenses << Offense.new(file: file, line: lines.first, severity: :error, message: message)
            next
          end

          if lines.size > 1 && RubyNative::Signals.singleton?(name)
            offenses << Offense.new(
              file: file,
              line: lines[1],
              severity: :warning,
              message: "#{lines.size} elements carry `#{name}`; only the first one is used."
            )
          end

          offenses.concat(version_offenses(file, name, lines.first))
        end

        offenses
      end

      # A signal newer than the installed gem is one the app was never told
      # about, so it is inert on device however correct it looks in the markup.
      def version_offenses(file, name, line)
        since = RubyNative::Signals.since(name)
        return [] unless since
        return [] if Gem::Version.new(RubyNative::VERSION) >= Gem::Version.new(since)

        [Offense.new(
          file: file,
          line: line,
          severity: :error,
          message: "`#{name}` needs Ruby Native #{since}, but this app is on #{RubyNative::VERSION}."
        )]
      end

      # --- Deployed build check ---

      # The gem version in the Gemfile says what the views may emit. The build
      # in the store says what the app can actually honor, and those drift
      # apart the moment someone bumps the gem without deploying.
      def deployed_offenses(files)
        app_id = config.dig(:ruby_native, :app_id)
        unless app_id
          puts "Skipping --deployed: no app_id in #{CONFIG_PATH}. Run `ruby_native deploy` once to link this app."
          return []
        end

        unless Credentials.token
          puts "Skipping --deployed: not logged in. Run `ruby_native login` first."
          return []
        end

        used = signals_in(files)
        PLATFORMS.flat_map { |platform| deployed_offenses_for(platform, app_id, used) }
      end

      def deployed_offenses_for(platform, app_id, used)
        built = latest_build_version(app_id, platform)
        return [] unless built

        used.filter_map do |name, (file, line)|
          since = RubyNative::Signals.since(name)
          next unless since
          next if Gem::Version.new(built) >= Gem::Version.new(since)

          Offense.new(
            file: file,
            line: line,
            severity: :error,
            message: "`#{name}` needs #{since}, but the #{platform} build users have was made on #{built}."
          )
        end
      end

      def signals_in(files)
        files.each_with_object({}) do |file, used|
          collector = SignalCollector.new
          Herb.parse(File.read(file, encoding: "UTF-8")).value.accept(collector)
          collector.signals.each { |name, lines| used[name] ||= [file, lines.first] }
        rescue StandardError
          next
        end
      end

      def latest_build_version(app_id, platform)
        uri = URI("#{HOST}/api/v1/apps/#{app_id}/builds/latest?platform=#{platform}")
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Token #{Credentials.token}"

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(request)
        end

        return nil unless response.is_a?(Net::HTTPSuccess)
        return nil if response.body.to_s.empty?

        JSON.parse(response.body)["gem_version"]
      rescue StandardError
        # A check that cannot reach the API should not fail the build; the
        # local checks above still ran and still mean something.
        puts "Skipping --deployed for #{platform}: could not reach #{HOST}."
        nil
      end

      def config
        @config ||= if File.exist?(CONFIG_PATH)
          YAML.load_file(CONFIG_PATH, symbolize_names: true, aliases: true) || {}
        else
          {}
        end
      rescue Psych::SyntaxError
        {}
      end

      # --- Reporting ---

      def report(files, offenses)
        puts self.class.report_lines(files, offenses)
      end

      def parse_paths(argv)
        flag = argv.find { |argument| argument.start_with?("--paths=") }
        return DEFAULT_PATHS unless flag

        flag.split("=", 2).last.split(",").map(&:strip).reject(&:empty?)
      end
    end
  end
end
