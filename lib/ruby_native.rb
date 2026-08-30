require "erb"
require "monitor"
require "ruby_native/version"
require "ruby_native/helper"
require "ruby_native/native_version"
require "ruby_native/native_detection"
require "ruby_native/inertia_support"
require "ruby_native/set_cookie_header"
require "ruby_native/oauth_middleware"
require "ruby_native/tunnel_cookie_middleware"
require "ruby_native/iap/event"
require "ruby_native/iap/verifiable"
require "ruby_native/iap/decodable"
require "ruby_native/iap/normalizable"
require "ruby_native/iap/apple_webhook_processor"
require "ruby_native/screenshots/sign_in_helper"
require "ruby_native/engine"

module RubyNative
  mattr_accessor :subscription_callbacks, default: []

  # Screenshot configuration. Set via `RubyNative.configure` in an initializer.
  mattr_accessor :screenshot_key
  mattr_accessor :screenshot_sign_in

  # How the push endpoint finds the signed-in user to attach a device token to.
  # Accepts a controller method name (Symbol) or a callable evaluated in the
  # controller, e.g. `-> { Current.person }`. Defaults to `current_user`, so
  # Devise apps need no configuration. Set via `RubyNative.configure`.
  mattr_accessor :current_user_resolver, default: :current_user

  def self.configure
    yield self
  end

  def self.on_subscription_change(&block)
    subscription_callbacks << block
  end

  def self.fire_subscription_callbacks(event)
    subscription_callbacks.each { |cb| cb.call(event) }
  end

  CONFIG_LOCK = Monitor.new
  private_constant :CONFIG_LOCK

  # Loaded on first read, not at boot: rendering the YAML's ERB runs asset
  # helpers, and under `assets:precompile` those run before the bundles are
  # built, leaving Propshaft's manifest without them.
  def self.config
    return @config if defined?(@config)

    CONFIG_LOCK.synchronize do
      load_config unless defined?(@config)
      @config = nil unless defined?(@config) # missing or empty file
      @config
    end
  end

  def self.config=(value)
    @config = value
  end

  def self.load_config
    path = Rails.root.join("config", "ruby_native.yml")
    return unless path.exist?

    parsed = YAML.load(render_config(path), filename: path.to_s, aliases: true)

    # An empty file, comments only, or ERB rendering to nothing parses to nil;
    # treat it like a missing file instead of raising.
    unless parsed.is_a?(Hash)
      Rails.logger.warn("[RubyNative] #{path} is empty or not a YAML mapping; ignoring it.")
      return
    end

    self.config = parsed.deep_symbolize_keys
    self.config[:app] ||= {}
    self.config[:app][:entry_path] ||= self.config.dig(:tabs, 0, :path) || "/"
    self.config[:auth] ||= {}
    normalize_oauth_paths
    normalize_linked_paths
    backfill_tab_icons
    backfill_error_icons
    warn_on_duplicate_tab_keys
    normalize_analytics
    normalize_firebase
  end

  # config/ruby_native.yml is rendered as ERB before it is parsed, so a
  # developer can interpolate Rails helpers into it. The motivating case is the
  # navbar logo: `logo: '<%= image_url("logo.png") %>'` resolves to a
  # fingerprinted asset URL the native app downloads and caches, and because the
  # digest changes whenever the asset changes, the cache busts itself. A full
  # URL (a CDN, say) works just as well; the app only ever sees a URL to fetch.
  #
  # The template renders against the controller helper proxy, so `image_url` and
  # friends behave exactly as they do in a view. With no request or asset host
  # they degrade to a relative path -- asset helpers never raise "missing host"
  # the way routing helpers do -- and the native app resolves any relative URL
  # against the base URL it already fetched the config from.
  def self.render_config(path)
    helpers = ActionController::Base.helpers
    ERB.new(path.read, trim_mode: "-").result(helpers.instance_eval { binding })
  end

  # Mirrors per-platform `icons:` into the legacy flat `icon:` field so native
  # binaries that only read `tab.icon` keep rendering an icon. Explicit `icon:`
  # wins; otherwise falls back to `icons.ios`, then `icons.android`.
  def self.backfill_tab_icons
    Array(self.config[:tabs]).each do |tab|
      next unless tab.is_a?(Hash)

      icons = tab[:icons]
      next unless icons.is_a?(Hash)

      tab[:icon] ||= icons[:ios] || icons[:android]
    end
  end

  # A tab's `key` names its copy in the host app's locale files, so two tabs
  # sharing one read the same translations and one of them is always
  # mislabeled. Warn rather than raise: both tabs still render, and a typo in
  # the config should never take down boot.
  def self.warn_on_duplicate_tab_keys
    keys = Array(self.config[:tabs]).filter_map { |tab| tab[:key] if tab.is_a?(Hash) }
    duplicates = keys.tally.select { |_, count| count > 1 }.keys
    return if duplicates.empty?

    Rails.logger.warn(
      "[RubyNative] Duplicate tab key(s) in config/ruby_native.yml " \
      "(#{duplicates.join(", ")}). Each tab needs its own key, or they share a title."
    )
  end

  # Mirrors `backfill_tab_icons` for the error screen: fills a state's flat
  # `icon` from its per-platform `icons` (ios first, then android), so the iOS
  # app, which reads only the flat `icon`, still renders one. An explicit
  # `icon:` wins.
  def self.backfill_error_icons
    errors = self.config[:errors]
    return unless errors.is_a?(Hash)

    ERROR_SCREEN_STATES.each do |state|
      state_config = errors[state]
      next unless state_config.is_a?(Hash)

      icons = state_config[:icons]
      next unless icons.is_a?(Hash)

      state_config[:icon] ||= icons[:ios] || icons[:android]
    end
  end

  # The native fallback screen has two states: `offline` (no connectivity) and
  # `generic` (any other load failure). Each can carry a per-platform icon and
  # localized copy.
  ERROR_SCREEN_STATES = %i[offline generic].freeze
  ERROR_SCREEN_COPY_KEYS = %i[title message].freeze

  # The JSON served at GET /native/config. Identical to `config`, except the
  # `errors` block is enriched: per-state icons from config/ruby_native.yml are
  # merged with localized title/message pulled from the host app's I18n
  # (`ruby_native.errors.<state>.<key>`), one entry per available locale. Only
  # values the developer actually provided are emitted; the native apps fall
  # back to bundled English copy for anything missing. Built on a deep copy so
  # the in-memory `config` the server reads for view helpers is never mutated.
  def self.config_as_json
    return config if config.nil?

    payload = config.deep_dup
    # Shipped app binaries have required the `appearance` key at decode; keep
    # emitting it so they still boot when the YAML omits the block.
    payload[:appearance] ||= {}
    localize_tab_titles(payload[:tabs])
    errors = error_screen_config(payload[:errors])
    if errors.empty?
      payload.delete(:errors)
    else
      payload[:errors] = errors
    end
    payload
  end

  # Fills each tab's `titles` from `ruby_native.tabs.<key>.title` in the host
  # app's locale files, mirroring the `ruby_native.errors.*` namespace. The map
  # is emitted beside the flat `title` rather than replacing it, the same
  # additive shape as `icon`/`icons`: both platforms decode `title` as a plain
  # String, so an app that does not read `titles` yet keeps rendering the YAML
  # copy. Tabs without a `key` are left exactly as authored.
  #
  # `title:` is optional in the YAML so a localized app can keep all of its copy
  # in locale files, but it is never optional on the wire: both platforms decode
  # it as a required, non-optional String, so a tab missing one fails the whole
  # config decode and drops the user on the error screen. Fill it from the
  # default locale, then from any locale that was translated.
  def self.localize_tab_titles(tabs)
    Array(tabs).each do |tab|
      next unless tab.is_a?(Hash)

      key = tab[:key].to_s
      titles = key.empty? ? {} : translations_for("tabs.#{key}.title")
      tab[:titles] = titles unless titles.empty?
      next unless tab[:title].to_s.empty?

      tab[:title] = titles[I18n.default_locale] || titles.values.first || fallback_tab_title(key)
    end
  end

  # Reached only when a tab has no `title:` and no translation in any locale,
  # which would otherwise serve a payload that cannot decode. Names the tab
  # after its key ("order_history" -> "Order history") so the bar still renders
  # something recognizable, and says so, since the copy is missing everywhere.
  def self.fallback_tab_title(key)
    if key.empty?
      Rails.logger.warn(
        "[RubyNative] A tab in config/ruby_native.yml has no `title:`. Give it one, or a `key:` " \
        "with copy under `ruby_native.tabs.<key>.title` in your locale files."
      )
      return "Untitled"
    end

    Rails.logger.warn(
      "[RubyNative] Tab #{key.inspect} in config/ruby_native.yml has no `title:` and no " \
      "`ruby_native.tabs.#{key}.title` translation in any locale. Falling back to a title from the key."
    )
    key.humanize
  end

  # Merges per-state error-screen icons (from YAML) with localized copy (from
  # I18n) into the shape the native apps decode. Omits any state with neither an
  # icon nor copy, so an untouched app sends no `errors` block at all.
  def self.error_screen_config(yaml_errors)
    config = ERROR_SCREEN_STATES.each_with_object({}) do |state, result|
      entry = {}
      state_config = yaml_errors[state] if yaml_errors.is_a?(Hash)
      if state_config.is_a?(Hash)
        entry[:icon] = state_config[:icon] if state_config[:icon]
        entry[:icons] = state_config[:icons] if state_config[:icons]
      end
      ERROR_SCREEN_COPY_KEYS.each do |key|
        translations = translations_for("errors.#{state}.#{key}")
        entry[key] = translations unless translations.empty?
      end
      result[state] = entry unless entry.empty?
    end

    # The Retry button label is shared by both states, so it sits at the top of
    # the block rather than under a state.
    retry_label = translations_for("errors.retry")
    config[:retry] = retry_label unless retry_label.empty?
    config
  end

  # Reads `ruby_native.<subkey>` for every available locale, keeping only the
  # locales the developer actually translated. Copy lives in the host app's own
  # locale files; the gem ships none.
  def self.translations_for(subkey)
    I18n.available_locales.each_with_object({}) do |locale, result|
      value = I18n.t("ruby_native.#{subkey}", locale: locale, default: nil)
      result[locale] = value unless value.nil?
    end
  end

  # `auth.oauth_paths` must list only OAuth authorize paths, never their
  # callbacks. The native app treats every listed path as a sign-in trigger and
  # derives the provider from the last path segment, so a callback entry like
  # "/auth/google/callback" would launch a bogus flow for a provider named
  # "callback" and send sign-in into a loop. The callback round-trip is handled
  # automatically by OAuthMiddleware's tracking cookie, so it never needs
  # listing. Drop any entry that is the "/callback" child of another listed
  # path and warn, so a copied-in callback can't break native sign-in. The value
  # is always written back as an array: a scalar in YAML fails the whole native
  # config decode on both platforms.
  def self.normalize_oauth_paths
    auth = self.config[:auth]
    return unless auth.is_a?(Hash) && auth.key?(:oauth_paths)

    paths = Array(auth[:oauth_paths])
    callbacks = paths.select { |path| paths.any? { |start| path == "#{start}/callback" } }
    if callbacks.any?
      Rails.logger.warn(
        "[RubyNative] Ignoring OAuth callback path(s) in config/ruby_native.yml " \
        "(#{callbacks.join(", ")}). List only the authorize path; callbacks are handled automatically."
      )
    end
    auth[:oauth_paths] = paths - callbacks
  end

  # Entries are path prefixes: "/pair/" links every URL under it. A leading
  # slash is added when missing, and a trailing "*" (an easy slip, since the
  # AASA file uses one) is stripped so both platforms receive a plain prefix.
  # Left absent when unconfigured so config.json doesn't grow an empty key.
  def self.normalize_linked_paths
    return unless self.config.key?(:linked_paths)

    self.config[:linked_paths] = Array(self.config[:linked_paths])
      .map { |path| path.to_s.strip.sub(/\*+\z/, "") }
      .reject(&:empty?)
      .map { |path| path.start_with?("/") ? path : "/#{path}" }
  end

  # A non-boolean, even the string "false", fails the native config decode on both platforms.
  def self.normalize_analytics
    return unless self.config.key?(:analytics)
    return if [true, false].include?(self.config[:analytics])

    Rails.logger.warn("[RubyNative] analytics in config/ruby_native.yml must be true or false; ignoring it.")
    self.config.delete(:analytics)
  end

  # An unquoted sender id parses as an Integer, and the Android app decodes these as strings only.
  def self.normalize_firebase
    firebase = self.config.dig(:android, :firebase)
    return unless firebase.is_a?(Hash)

    firebase.transform_values! { |value| value.nil? ? value : value.to_s }
  end
end
