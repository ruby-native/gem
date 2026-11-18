require "test_helper"

class RubyNative::ConfigAsJsonTest < Minitest::Test
  def teardown
    reset_config
    I18n.backend.reload!
    I18n.available_locales = nil
  end

  def test_omits_errors_block_when_unconfigured
    RubyNative.load_config
    refute RubyNative.config_as_json.key?(:errors)
  end

  def test_merges_per_platform_icons_with_localized_copy
    store_translations(:en, offline: {title: "You're offline", message: "Check your connection."})
    store_translations(:it, offline: {title: "Sei offline", message: "Controlla la connessione."})
    I18n.available_locales = [:en, :it]

    with_errors_config do
      offline = RubyNative.config_as_json[:errors][:offline]
      assert_equal({ios: "wifi.slash", android: "wifi_off"}, offline[:icons])
      assert_equal "wifi.slash", offline[:icon] # backfilled from icons.ios, like tabs
      assert_equal "You're offline", offline[:title][:en]
      assert_equal "Sei offline", offline[:title][:it]
      assert_equal "Controlla la connessione.", offline[:message][:it]
    end
  end

  def test_only_emits_locales_the_developer_translated
    store_translations(:it, generic: {title: "Qualcosa è andato storto"})
    I18n.available_locales = [:en, :it]

    with_errors_config do
      generic = RubyNative.config_as_json[:errors][:generic]
      assert_equal({it: "Qualcosa è andato storto"}, generic[:title])
      refute generic.key?(:message), "message has no translation in any locale"
    end
  end

  def test_emits_icon_only_state_without_copy
    I18n.available_locales = [:en]

    with_errors_config do
      offline = RubyNative.config_as_json[:errors][:offline]
      assert_equal "wifi.slash", offline[:icons][:ios]
      refute offline.key?(:title)
      refute offline.key?(:message)
    end
  end

  def test_does_not_mutate_in_memory_config
    store_translations(:en, offline: {title: "You're offline"})
    I18n.available_locales = [:en]

    with_errors_config do
      RubyNative.config_as_json
      # The server-side config holds only the YAML icons. The localized copy is
      # merged into the JSON payload on a deep copy, never back into `config`.
      refute RubyNative.config[:errors][:offline].key?(:title)
    end
  end

  def test_emits_shared_retry_label
    store_translations(:en, retry: "Retry")
    store_translations(:it, retry: "Riprova")
    I18n.available_locales = [:en, :it]

    with_errors_config do
      retry_label = RubyNative.config_as_json[:errors][:retry]
      assert_equal "Retry", retry_label[:en]
      assert_equal "Riprova", retry_label[:it]
    end
  end

  def test_emits_errors_block_for_retry_only
    store_translations(:en, retry: "Retry")
    I18n.available_locales = [:en]
    RubyNative.load_config

    errors = RubyNative.config_as_json[:errors]
    assert_equal({en: "Retry"}, errors[:retry])
    refute errors.key?(:offline)
    refute errors.key?(:generic)
  end

  def test_single_icon_is_emitted_without_per_platform_icons
    I18n.available_locales = [:en]
    write_config(
      app: {name: "Test App"},
      appearance: {tint_color: "#007AFF", background_color: "#FFFFFF"},
      tabs: [{title: "Home", path: "/", icon: "house"}],
      errors: {generic: {icon: "warning"}}
    )
    RubyNative.load_config

    generic = RubyNative.config_as_json[:errors][:generic]
    assert_equal "warning", generic[:icon]
    refute generic.key?(:icons)
  end

  def test_emits_empty_appearance_when_the_block_is_omitted
    write_config(
      app: {name: "Test App"},
      tabs: [{title: "Home", path: "/", icon: "house"}]
    )
    RubyNative.load_config

    # Shipped app binaries require the key at decode; it must always be present.
    assert_equal({}, RubyNative.config_as_json[:appearance])
  end

  def test_localizes_tab_titles_from_the_key
    store_tab_translations(:en, home: {title: "Home"})
    store_tab_translations(:it, home: {title: "Casa"})
    I18n.available_locales = [:en, :it]

    with_tabs_config([{title: "Home", key: "home", path: "/", icon: "house"}]) do
      tab = RubyNative.config_as_json[:tabs].first
      assert_equal "Home", tab[:title] # the flat string old binaries decode
      assert_equal({en: "Home", it: "Casa"}, tab[:titles])
    end
  end

  def test_leaves_a_tab_without_a_key_alone
    store_tab_translations(:it, home: {title: "Casa"})
    I18n.available_locales = [:en, :it]

    with_tabs_config([{title: "Home", path: "/", icon: "house"}]) do
      tab = RubyNative.config_as_json[:tabs].first
      assert_equal "Home", tab[:title]
      refute tab.key?(:titles)
    end
  end

  def test_only_emits_locales_the_developer_translated_for_tabs
    store_tab_translations(:it, home: {title: "Casa"})
    I18n.available_locales = [:en, :it]

    with_tabs_config([{title: "Home", key: "home", path: "/", icon: "house"}]) do
      assert_equal({it: "Casa"}, RubyNative.config_as_json[:tabs].first[:titles])
    end
  end

  def test_a_yaml_title_wins_over_the_default_locale_translation
    store_tab_translations(:en, home: {title: "Translated"})
    I18n.available_locales = [:en]

    with_tabs_config([{title: "Authored", key: "home", path: "/", icon: "house"}]) do
      tab = RubyNative.config_as_json[:tabs].first
      assert_equal "Authored", tab[:title]
      assert_equal({en: "Translated"}, tab[:titles])
    end
  end

  # The point of the key: an app that translates every tab can drop `title:`
  # and keep all of its copy in locale files. Both platforms decode `title` as
  # a required String, so one is always synthesized for the wire.
  def test_synthesizes_the_flat_title_from_the_default_locale
    store_tab_translations(:en, home: {title: "Home"})
    store_tab_translations(:it, home: {title: "Casa"})
    I18n.available_locales = [:en, :it]

    with_tabs_config([{key: "home", path: "/", icon: "house"}]) do
      tab = RubyNative.config_as_json[:tabs].first
      assert_equal "Home", tab[:title]
      assert_equal({en: "Home", it: "Casa"}, tab[:titles])
    end
  end

  def test_synthesizes_the_flat_title_from_any_locale_when_the_default_is_untranslated
    store_tab_translations(:it, home: {title: "Casa"})
    I18n.available_locales = [:en, :it]

    with_tabs_config([{key: "home", path: "/", icon: "house"}]) do
      assert_equal "Casa", RubyNative.config_as_json[:tabs].first[:title]
    end
  end

  # A payload with a null title fails decode on both platforms and drops the
  # user on the error screen, so an untranslated tab still ships a string.
  def test_falls_back_to_the_key_when_a_tab_has_no_copy_anywhere
    I18n.available_locales = [:en]

    log = with_captured_log do
      with_tabs_config([{key: "order_history", path: "/orders", icon: "bag"}]) do
        tab = RubyNative.config_as_json[:tabs].first
        assert_equal "Order history", tab[:title]
        refute tab.key?(:titles)
      end
    end
    assert_includes log, "ruby_native.tabs.order_history.title"
  end

  def test_does_not_mutate_the_in_memory_tabs
    store_tab_translations(:it, home: {title: "Casa"})
    I18n.available_locales = [:it]

    with_tabs_config([{title: "Home", key: "home", path: "/", icon: "house"}]) do
      RubyNative.config_as_json
      # View helpers read `config`; the localized copy only ever rides the JSON.
      refute RubyNative.config[:tabs].first.key?(:titles)
    end
  end

  def test_navbar_appearance_passes_through
    write_config(
      app: {name: "Test App"},
      appearance: {
        background_color: "#FFFFFF",
        navbar: {
          logo: "https://cdn.example.com/logo.png",
          background_color: "#3B3F54",
          foreground_color: "#FFFFFF"
        }
      },
      tabs: [{title: "Home", path: "/", icon: "house"}]
    )
    RubyNative.load_config

    navbar = RubyNative.config_as_json[:appearance][:navbar]
    assert_equal "https://cdn.example.com/logo.png", navbar[:logo]
    assert_equal "#3B3F54", navbar[:background_color]
    assert_equal "#FFFFFF", navbar[:foreground_color]
  end

  def test_light_and_dark_logo_goes_out_as_logo_and_logo_dark
    write_config(
      app: {name: "Test App"},
      appearance: {navbar: {logo: {light: "/logo.png", dark: "/logo-dark.png"}}},
      tabs: [{title: "Home", path: "/", icon: "house"}]
    )
    RubyNative.load_config

    navbar = RubyNative.config_as_json[:appearance][:navbar]
    assert_equal "/logo.png", navbar[:logo]
    assert_equal "/logo-dark.png", navbar[:logo_dark]
    assert_equal({light: "/logo.png", dark: "/logo-dark.png"}, RubyNative.config.dig(:appearance, :navbar, :logo))
  end

  def test_emits_analytics_false
    with_analytics_config(false) do
      assert_equal false, RubyNative.config_as_json[:analytics]
    end
  end

  # Both platforms decode `analytics` as an optional Bool, so a string like
  # "no" would fail the whole config decode. It is dropped instead.
  def test_drops_a_non_boolean_analytics_value_and_warns
    log = with_captured_log do
      with_analytics_config("no") do
        refute RubyNative.config_as_json.key?(:analytics)
      end
    end
    assert_includes log, "analytics in config/ruby_native.yml must be true or false; ignoring it."
  end

  def test_omits_analytics_when_unconfigured
    RubyNative.load_config
    refute RubyNative.config_as_json.key?(:analytics)
  end

  private

  def store_translations(locale, states)
    I18n.backend.store_translations(locale, ruby_native: {errors: states})
  end

  def store_tab_translations(locale, tabs)
    I18n.backend.store_translations(locale, ruby_native: {tabs: tabs})
  end

  def with_analytics_config(value)
    write_config(
      app: {name: "Test App"},
      appearance: {tint_color: "#007AFF", background_color: "#FFFFFF"},
      tabs: [{title: "Home", path: "/", icon: "house"}],
      analytics: value
    )
    RubyNative.load_config
    yield
  end

  def with_tabs_config(tabs)
    write_config(
      app: {name: "Test App"},
      appearance: {tint_color: "#007AFF", background_color: "#FFFFFF"},
      tabs: tabs
    )
    RubyNative.load_config
    yield
  end

  def with_captured_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  def with_errors_config
    write_config(
      app: {name: "Test App"},
      appearance: {tint_color: "#007AFF", background_color: "#FFFFFF"},
      tabs: [{title: "Home", path: "/", icon: "house"}],
      errors: {
        offline: {icons: {ios: "wifi.slash", android: "wifi_off"}},
        generic: {icons: {ios: "exclamationmark.triangle", android: "error_outline"}}
      }
    )
    RubyNative.load_config
    yield
  end

  def write_config(hash)
    config_path.write(hash.deep_stringify_keys.to_yaml)
  end

  def reset_config
    config_path.write(default_yaml)
    RubyNative.load_config
  end

  def config_path
    Rails.root.join("config", "ruby_native.yml")
  end

  def default_yaml
    <<~YAML
      app:
        name: Test App
      appearance:
        tint_color: "#007AFF"
        background_color: "#FFFFFF"
      tabs:
        - title: Home
          path: /
          icon: house
      auth:
        oauth_paths:
          - /auth/test_provider
    YAML
  end
end
