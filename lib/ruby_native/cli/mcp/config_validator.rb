require "yaml"

module RubyNative
  class CLI
    class Mcp
      # Static validation of config/ruby_native.yml.
      #
      # Every rule mirrors something that already happens at runtime: a value
      # `RubyNative.load_config` normalizes away with a log line nobody reads,
      # or one that fails the config decode on device and drops the user on the
      # error screen instead of the app. The severities follow that split --
      # `error` means the app does not boot, `warning` means the setting is
      # quietly ignored.
      #
      # Rails is never booted: the CLI runs outside it, and the point is to
      # answer before a server does.
      class ConfigValidator
        DEFAULT_PATH = "config/ruby_native.yml".freeze

        # The whole top-level vocabulary. `app`, `appearance`, `tabs`, `auth`,
        # `errors`, and `analytics` are decoded on device; `ios`, `android`, and
        # `linked_paths` are served as universal-link metadata by the engine;
        # `ruby_native` holds the app_id `deploy` writes.
        TOP_LEVEL_KEYS = %w[app appearance tabs auth errors analytics ios android linked_paths ruby_native].freeze
        APP_KEYS = %w[name mode entry_path].freeze
        # `android` is the per-platform chrome block, read only by the Android app.
        APPEARANCE_KEYS = %w[tint_color background_color theme landscape navbar splash android].freeze
        NAVBAR_KEYS = %w[logo background_color foreground_color status_bar].freeze
        SPLASH_KEYS = %w[enabled spinner_color status_bar].freeze
        TAB_KEYS = %w[title titles path icon icons key eager search badge auto_route].freeze

        MODES = %w[normal advanced].freeze
        THEMES = %w[auto light dark].freeze
        STATUS_BARS = %w[light dark].freeze

        # UIColor(hex:) takes exactly six hex digits and an optional `#`. A
        # three-digit shorthand parses as nil, which reads on device as the
        # color simply not applying.
        HEX_COLOR = /\A#?\h{6}\z/

        # The file is rendered as ERB before Rails parses it, so a navbar logo
        # can interpolate `image_url`. There is no Rails here to render against,
        # so tags become a sentinel: the document stays valid YAML, and no rule
        # fires on a value this file cannot know.
        ERB_TAG = /<%=?-?.*?-?%>/m
        ERB_SENTINEL = "ruby-native-erb-value".freeze

        Offense = Struct.new(:key, :line, :severity, :message, keyword_init: true)

        def self.run(path: DEFAULT_PATH)
          new(path).run
        end

        def initialize(path = DEFAULT_PATH)
          @path = path
          @offenses = []
          @lines = []
        end

        def run
          unless File.exist?(@path)
            return [Offense.new(
              key: nil,
              line: nil,
              severity: :error,
              message: "#{@path} does not exist. Run `rails generate ruby_native:install` to create it."
            )]
          end

          source = File.read(@path, encoding: "UTF-8")
          @lines = source.lines
          @erb = source.match?(ERB_TAG)

          config = parse(source)
          return @offenses if @parse_failed

          unless config.is_a?(Hash)
            error(nil, "#{@path} is empty or is not a YAML mapping, so Ruby Native ignores the whole file and the app boots unconfigured.")
            return @offenses
          end

          check_top_level(config)
          check_app(config["app"])
          check_appearance(config["appearance"])
          check_tabs(config["tabs"])
          check_auth(config["auth"])
          check_analytics(config)
          check_linked_paths(config["linked_paths"])
          check_identifiers(config["ios"], "ios", %w[bundle_id team_id], "/.well-known/apple-app-site-association")
          check_identifiers(config["android"], "android", %w[package cert_fingerprint], "/.well-known/assetlinks.json")

          @offenses
        end

        private

        def parse(source)
          YAML.load(source.gsub(ERB_TAG, ERB_SENTINEL), aliases: true)
        rescue Psych::SyntaxError => syntax_error
          @parse_failed = true

          # Stubbing out `<%= %>` keeps a value-position tag valid, but a tag
          # that opens a block takes structure with it. That is this command's
          # blind spot, not the developer's mistake, so it says so rather than
          # reporting a syntax error the file does not have.
          if @erb
            warning(nil, "Could not check #{@path}: stubbing out its ERB left YAML that does not parse (#{syntax_error.problem}). " \
                         "That happens when a tag spans structure rather than filling in one value, and it does not mean the file is broken.",
              line: syntax_line(syntax_error))
          else
            error(nil, "#{@path} is not valid YAML: #{syntax_error.problem}. Rails cannot load it, so the app has no config at all.",
              line: syntax_line(syntax_error))
          end
          nil
        end

        # libyaml counts lines from zero and reports where it gave up, which can
        # be the line after the mistake or the end of the file. Adding one and
        # clamping to the file puts every shape of that back on a real line.
        def syntax_line(syntax_error)
          [[syntax_error.line + 1, @lines.size].min, 1].max
        end

        # --- Sections ---

        def check_top_level(config)
          config.each_key do |key|
            next if TOP_LEVEL_KEYS.include?(key.to_s)

            warning(key.to_s, "Unknown top-level key `#{key}`, which Ruby Native ignores. It reads: #{TOP_LEVEL_KEYS.join(", ")}.")
          end
        end

        def check_app(app)
          return if app.nil?
          return error("app", "`app` has to be a mapping.") unless app.is_a?(Hash)

          unknown_keys(app, APP_KEYS, "app")

          mode = app["mode"]
          if mode && !sentinel?(mode) && !MODES.include?(mode.to_s)
            warning("app.mode", "`app.mode` is #{mode.inspect}. The app matches it against #{MODES.join(" and ")} and runs Normal Mode for anything else, so a typo here is silent.")
          end

          entry = app["entry_path"]
          if entry.is_a?(String) && !sentinel?(entry) && !entry.start_with?("/")
            warning("app.entry_path", "`app.entry_path` is #{entry.inspect}. It is a path the app opens on launch, so write it absolute: \"/#{entry}\".")
          end
        end

        def check_appearance(appearance)
          return if appearance.nil?
          return error("appearance", "`appearance` has to be a mapping.") unless appearance.is_a?(Hash)

          unknown_keys(appearance, APPEARANCE_KEYS, "appearance")
          check_color(appearance["tint_color"], "appearance.tint_color")
          check_color(appearance["background_color"], "appearance.background_color")
          check_enum(appearance["theme"], "appearance.theme", THEMES)
          check_boolean(appearance["landscape"], "appearance.landscape")
          check_navbar(appearance["navbar"])
          check_splash(appearance["splash"])
        end

        def check_navbar(navbar)
          return if navbar.nil?
          return error("appearance.navbar", "`appearance.navbar` has to be a mapping.") unless navbar.is_a?(Hash)

          unknown_keys(navbar, NAVBAR_KEYS, "appearance.navbar")
          check_color(navbar["background_color"], "appearance.navbar.background_color")
          check_color(navbar["foreground_color"], "appearance.navbar.foreground_color")
          check_enum(navbar["status_bar"], "appearance.navbar.status_bar", STATUS_BARS)
        end

        def check_splash(splash)
          return if splash.nil?
          return error("appearance.splash", "`appearance.splash` has to be a mapping.") unless splash.is_a?(Hash)

          unknown_keys(splash, SPLASH_KEYS, "appearance.splash")
          check_boolean(splash["enabled"], "appearance.splash.enabled")
          check_color(splash["spinner_color"], "appearance.splash.spinner_color")
          check_enum(splash["status_bar"], "appearance.splash.status_bar", STATUS_BARS)
        end

        def check_tabs(tabs)
          return if tabs.nil?
          return error("tabs", "`tabs` has to be a list of tabs.") unless tabs.is_a?(Array)

          keys = []

          tabs.each_with_index do |tab, index|
            location = "tabs[#{index}]"

            unless tab.is_a?(Hash)
              error(location, "`#{location}` has to be a mapping with a title, a path, and an icon.")
              next
            end

            unknown_keys(tab, TAB_KEYS, location)
            check_tab_path(tab, location)
            check_tab_icon(tab, location)
            check_tab_title(tab, location)
            %w[eager search badge].each { |flag| check_boolean(tab[flag], "#{location}.#{flag}") }
            check_auto_route(tab["auto_route"], "#{location}.auto_route")

            keys << tab["key"].to_s if tab["key"]
          end

          duplicate_keys(keys)
        end

        def check_tab_path(tab, location)
          path = tab["path"]

          if path.nil?
            error("#{location}.path", "`#{location}` has no `path`. Every tab needs one, and without it the whole config fails to decode: the app shows its error screen instead of your tabs.")
          elsif path.is_a?(String) && !sentinel?(path) && !path.start_with?("/")
            warning("#{location}.path", "`#{location}.path` is #{path.inspect}. Tab paths are absolute, so write it as \"/#{path}\".")
          end
        end

        # `icon` is a required String on both platforms. The gem backfills it
        # from `icons.ios` or `icons.android`, so either form satisfies it.
        def check_tab_icon(tab, location)
          icons = tab["icons"]
          return if tab["icon"].is_a?(String) && !tab["icon"].empty?
          return if icons.is_a?(Hash) && (icons["ios"] || icons["android"])

          error("#{location}.icon", "`#{location}` has no icon. Give it `icon:`, or `icons:` with `ios:` or `android:`. Without one the whole config fails to decode and the app shows its error screen. Icon names: https://rubynative.com/docs/icons")
        end

        # `title` is optional in YAML only because locale files can carry it.
        # With neither, the gem names the tab after its key, or "Untitled".
        def check_tab_title(tab, location)
          return if tab["title"].is_a?(String) && !tab["title"].empty?

          if tab["key"]
            warning("#{location}.title", "`#{location}` has no `title`, so its label comes from `ruby_native.tabs.#{tab["key"]}.title` in your locale files. Make sure that key exists, or the tab falls back to a title built from #{tab["key"].to_s.inspect}.")
          else
            warning("#{location}.title", "`#{location}` has no `title` and no `key`, so the tab renders as \"Untitled\". Give it a title, or a key with copy under `ruby_native.tabs.<key>.title`.")
          end
        end

        def check_auto_route(value, key)
          return if value.nil? || value == false || value.is_a?(Array)

          if value == true
            error(key, "`#{key}` is true, which the app rejects outright: the config fails to decode and the user gets the error screen. Use false to never switch to this tab, or a list of path prefixes.")
          else
            error(key, "`#{key}` is #{value.inspect}. It takes false, or a list of path prefixes like [\"/orders/\"]. Anything else fails the config decode.")
          end
        end

        def check_auth(auth)
          return if auth.nil?
          return error("auth", "`auth` has to be a mapping.") unless auth.is_a?(Hash)

          paths = auth["oauth_paths"]
          return if paths.nil?

          unless paths.is_a?(Array)
            warning("auth.oauth_paths", "`auth.oauth_paths` is a single value. Ruby Native reads it as a list of one, but write it as a list.")
            return
          end

          paths.select { |path| paths.any? { |start| path == "#{start}/callback" } }.each do |callback|
            warning("auth.oauth_paths", "`auth.oauth_paths` lists #{callback.inspect}. List only the authorize path: Ruby Native drops callbacks, and the app would otherwise read the last segment as a provider named \"callback\" and loop sign-in.")
          end
        end

        def check_analytics(config)
          return unless config.key?("analytics")

          value = config["analytics"]
          return if value == true || value == false

          warning("analytics", "`analytics` is #{value.inspect}. It has to be true or false; Ruby Native drops anything else, including the string \"false\", and keeps reporting.")
        end

        def check_linked_paths(paths)
          return if paths.nil?
          return error("linked_paths", "`linked_paths` has to be a list of path prefixes.") unless paths.is_a?(Array)

          paths.each do |path|
            text = path.to_s

            if text.end_with?("*")
              warning("linked_paths", "`linked_paths` lists #{path.inspect}. Ruby Native strips the trailing `*` -- the AASA file uses one, this file takes a plain prefix -- so drop it here.")
            elsif !text.start_with?("/")
              warning("linked_paths", "`linked_paths` lists #{path.inspect}. Entries are absolute prefixes; Ruby Native rewrites it to \"/#{text}\".")
            end
          end
        end

        def check_identifiers(section, key, required, endpoint)
          return if section.nil?
          return error(key, "`#{key}` has to be a mapping.") unless section.is_a?(Hash)

          missing = required.select { |field| section[field].to_s.strip.empty? }
          return if missing.empty?

          warning(key, "`#{key}` is missing #{missing.map { |field| "`#{field}`" }.join(" and ")}. Your app serves #{endpoint} only once both are set, so universal links and shared passwords stay off until then.")
        end

        # --- Value checks ---

        def check_color(value, key)
          return if value.nil?

          case value
          when String
            return if sentinel?(value) || value.match?(HEX_COLOR)

            warning(key, "`#{key}` is #{value.inspect}, which is not a six-digit hex color. The app cannot read it and falls back to its default, with nothing said either way. Write it as \"#RRGGBB\".")
          when Hash
            missing = %w[light dark] - value.keys.map(&:to_s)

            if missing.any?
              error(key, "`#{key}` is a mapping without #{missing.map { |field| "`#{field}`" }.join(" and ")}. A per-theme color needs both, or the config fails to decode and the app shows its error screen.")
            else
              check_color(value["light"], "#{key}.light")
              check_color(value["dark"], "#{key}.dark")
            end
          else
            error(key, "`#{key}` is #{value.inspect}. A color is a hex string like \"#007AFF\", or a mapping with `light` and `dark`. Anything else fails the config decode and the app shows its error screen.")
          end
        end

        def check_boolean(value, key)
          return if value.nil? || value == true || value == false

          error(key, "`#{key}` is #{value.inspect}. It has to be true or false, or the config fails to decode and the app shows its error screen.")
        end

        def check_enum(value, key, allowed)
          return if value.nil? || sentinel?(value)
          return if allowed.include?(value.to_s)

          error(key, "`#{key}` is #{value.inspect}. It takes #{allowed.join(", ")}; anything else fails the config decode and the app shows its error screen.")
        end

        def unknown_keys(section, known, prefix)
          section.each_key do |key|
            next if known.include?(key.to_s)

            warning("#{prefix}.#{key}", "Unknown key `#{key}` under `#{prefix}`, which Ruby Native ignores. It reads: #{known.join(", ")}.")
          end
        end

        # A tab's key names its copy in the host app's locale files, so two tabs
        # sharing one read the same translations and one is always mislabeled.
        def duplicate_keys(keys)
          keys.tally.select { |_, count| count > 1 }.each_key do |key|
            warning("tabs", "Two or more tabs share the key #{key.inspect}, so they read the same translations and one of them is always mislabeled. Give each tab its own key.")
          end
        end

        # --- Offenses ---

        def error(key, message, line: nil)
          add(:error, key, message, line)
        end

        def warning(key, message, line: nil)
          add(:warning, key, message, line)
        end

        def add(severity, key, message, line)
          @offenses << Offense.new(key: key, line: line || line_for(key), severity: severity, message: message)
        end

        # Walks the file the way the key path walks the document: `tabs[1].icon`
        # finds `tabs:`, then the second list item under it, then `icon:` inside
        # that item. A missing leaf falls back to the block that should have
        # held it, which is where the fix goes. Every other dead end returns
        # nil: a wrong line number sends a reader somewhere else entirely,
        # which is worse than sending them nowhere.
        def line_for(key)
          return nil if key.nil?

          segments = key.to_s.split(".")
          first = 0
          last = @lines.size
          line = nil

          segments.each_with_index do |segment, position|
            name, index = segment.match(/\A([^\[]*)(?:\[(\d+)\])?\z/).captures

            unless name.empty?
              found = find_key(name, first, last)
              return position == segments.size - 1 && line ? line + 1 : nil unless found

              line = found
              first, last = block_bounds(found)
            end

            if index
              bounds = item_bounds(first, last, index.to_i)
              return nil unless bounds

              first, last = bounds
              line = first
            end
          end

          line ? line + 1 : nil
        end

        # The first line in range holding `name:`, preferring the shallowest
        # indentation so a direct child wins over one nested deeper. Comments
        # never match, since the `#` lands where the key would.
        def find_key(name, first, last)
          pattern = /\A\s*(?:-\s+)?#{Regexp.escape(name)}\s*:/

          (first...last)
            .select { |index| @lines[index].match?(pattern) }
            .min_by { |index| [indent(index), index] }
        end

        # The lines a key owns: everything under it indented deeper than it is.
        def block_bounds(line)
          depth = indent(line)
          finish = ((line + 1)...@lines.size).find { |index| meaningful?(index) && indent(index) <= depth }

          [line + 1, finish || @lines.size]
        end

        # The lines of the nth `- ` item in range, counting only items at the
        # shallowest dash indentation so a nested list is not mistaken for one.
        def item_bounds(first, last, wanted)
          starts = (first...last).select { |index| @lines[index].match?(/\A\s*-\s/) }
          return nil if starts.empty?

          depth = starts.map { |index| indent(index) }.min
          starts = starts.select { |index| indent(index) == depth }
          start = starts[wanted]
          return nil unless start

          [start, starts[wanted + 1] || last]
        end

        def indent(line)
          @lines[line][/\A */].length
        end

        def meaningful?(line)
          !@lines[line].match?(/\A\s*(#|\z)/)
        end

        def sentinel?(value)
          value.is_a?(String) && value.include?(ERB_SENTINEL)
        end
      end
    end
  end
end
