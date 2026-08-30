require "test_helper"

class RubyNative::ConfigTest < Minitest::Test
  def teardown
    RubyNative.load_config
  end

  def test_load_config_reads_yaml
    RubyNative.load_config
    refute_nil RubyNative.config
  end

  def test_config_is_not_loaded_while_rails_boots
    refute CONFIG_LOADED_AT_BOOT, "the dummy app read RubyNative.config during boot"
  end

  def test_config_loads_on_first_read
    RubyNative.load_config
    RubyNative.remove_instance_variable(:@config)

    assert_equal "Test App", RubyNative.config[:app][:name]
  end

  def test_a_nil_config_is_not_reloaded_on_read
    RubyNative.config = nil

    assert_nil RubyNative.config
  end

  def test_config_is_deep_symbolized
    RubyNative.load_config
    assert_equal "Test App", RubyNative.config[:app][:name]
  end

  def test_config_has_tabs
    RubyNative.load_config
    tabs = RubyNative.config[:tabs]
    assert_equal 1, tabs.length
    assert_equal "Home", tabs.first[:title]
    assert_equal "/", tabs.first[:path]
  end

  def test_config_has_appearance
    RubyNative.load_config
    appearance = RubyNative.config[:appearance]
    assert_equal "#007AFF", appearance[:tint_color]
  end

  def test_entry_path_defaults_to_first_tab_path
    with_config(app: {}, tabs: [{title: "Inbox", path: "/inbox", icon: "tray"}]) do
      RubyNative.load_config
      assert_equal "/inbox", RubyNative.config[:app][:entry_path]
    end
  end

  def test_entry_path_defaults_to_slash_when_no_tabs
    with_config(app: {}, tabs: []) do
      RubyNative.load_config
      assert_equal "/", RubyNative.config[:app][:entry_path]
    end
  end

  def test_entry_path_not_overwritten_when_present
    with_config(app: {entry_path: "/dashboard"}, tabs: [{title: "Home", path: "/", icon: "house"}]) do
      RubyNative.load_config
      assert_equal "/dashboard", RubyNative.config[:app][:entry_path]
    end
  end

  def test_linked_paths_are_normalized_to_plain_prefixes
    with_config(app: {}, tabs: [], linked_paths: [ "/pair/*", "invites/", " ", nil ]) do
      RubyNative.load_config
      assert_equal [ "/pair/", "/invites/" ], RubyNative.config[:linked_paths]
    end
  end

  def test_android_firebase_values_are_served_as_strings
    with_config(app: {}, tabs: [], android: { firebase: { app_id: "1:1:android:a", sender_id: 1234567890 } }) do
      RubyNative.load_config
      assert_equal "1234567890", RubyNative.config_as_json.dig(:android, :firebase, :sender_id)
    end
  end

  def test_linked_paths_stay_absent_when_unconfigured
    with_config(app: {}, tabs: []) do
      RubyNative.load_config
      refute RubyNative.config.key?(:linked_paths)
    end
  end

  def test_tab_icon_kept_when_explicitly_set
    with_config(app: {}, tabs: [{title: "Home", path: "/", icon: "house", icons: {ios: "house.fill", android: "home"}}]) do
      RubyNative.load_config
      assert_equal "house", RubyNative.config[:tabs].first[:icon]
    end
  end

  def test_tab_icon_backfilled_from_icons_ios
    with_config(app: {}, tabs: [{title: "Profile", path: "/profile", icons: {ios: "person.circle", android: "account_circle"}}]) do
      RubyNative.load_config
      assert_equal "person.circle", RubyNative.config[:tabs].first[:icon]
    end
  end

  def test_tab_icon_backfilled_from_icons_android_when_no_ios
    with_config(app: {}, tabs: [{title: "Profile", path: "/profile", icons: {android: "account_circle"}}]) do
      RubyNative.load_config
      assert_equal "account_circle", RubyNative.config[:tabs].first[:icon]
    end
  end

  def test_oauth_callback_path_duplicating_authorize_path_is_stripped
    with_config(app: {}, tabs: [], auth: {oauth_paths: ["/users/auth/google_oauth2", "/users/auth/google_oauth2/callback"]}) do
      RubyNative.load_config
      assert_equal ["/users/auth/google_oauth2"], RubyNative.config[:auth][:oauth_paths]
    end
  end

  def test_oauth_paths_without_callbacks_are_unchanged
    with_config(app: {}, tabs: [], auth: {oauth_paths: ["/auth/google", "/auth/github"]}) do
      RubyNative.load_config
      assert_equal ["/auth/google", "/auth/github"], RubyNative.config[:auth][:oauth_paths]
    end
  end

  def test_oauth_callback_without_a_matching_authorize_path_is_kept
    with_config(app: {}, tabs: [], auth: {oauth_paths: ["/users/auth/every/callback"]}) do
      RubyNative.load_config
      assert_equal ["/users/auth/every/callback"], RubyNative.config[:auth][:oauth_paths]
    end
  end

  def test_a_scalar_oauth_path_is_coerced_to_an_array
    with_config(app: {}, tabs: [], auth: {oauth_paths: "/auth/google"}) do
      RubyNative.load_config
      assert_equal ["/auth/google"], RubyNative.config[:auth][:oauth_paths]
    end
  end

  def test_a_scalar_oauth_path_is_coerced_in_the_config_json
    with_config(app: {}, tabs: [], auth: {oauth_paths: "/auth/google"}) do
      RubyNative.load_config
      assert_equal ["/auth/google"], RubyNative.config_as_json[:auth][:oauth_paths]
    end
  end

  def test_oauth_paths_stay_absent_when_unconfigured
    with_config(app: {}, tabs: []) do
      RubyNative.load_config
      refute RubyNative.config[:auth].key?(:oauth_paths)
    end
  end

  def test_config_is_rendered_as_erb
    with_raw_config(<<~YAML) do
      app:
        name: "<%= ["Ruby", "Native"].join(" ") %>"
      tabs: []
    YAML
      RubyNative.load_config
      assert_equal "Ruby Native", RubyNative.config[:app][:name]
    end
  end

  def test_erb_binding_exposes_asset_helpers
    # The navbar logo relies on `image_url` resolving inside the config. We can't
    # exercise a real asset without a pipeline in the dummy app, but asserting
    # the helper is in scope proves the ERB binding is the view helper context.
    with_raw_config(<<~YAML) do
      app:
        name: App
      tabs: []
      appearance:
        navbar:
          logo: "<%= respond_to?(:image_url) %>"
    YAML
      RubyNative.load_config
      assert_equal "true", RubyNative.config[:appearance][:navbar][:logo]
    end
  end

  # A nil parse (empty file, comments only) used to crash Rails boot with a
  # NoMethodError pointing into the gem.
  def test_an_empty_config_file_is_ignored_with_a_warning
    RubyNative.load_config
    log = with_captured_log do
      with_raw_config("# nothing configured yet\n") do
        RubyNative.load_config
        assert_equal "Test App", RubyNative.config[:app][:name]
      end
    end
    assert_includes log, "ruby_native.yml"
  end

  def test_erb_rendering_to_nothing_is_ignored
    with_captured_log do
      with_raw_config("<% if false %>\napp:\n  name: Hidden\n<% end %>\n") do
        RubyNative.load_config
      end
    end
  end

  def test_yaml_syntax_errors_name_the_config_file
    with_raw_config("app: [\n") do
      error = assert_raises(Psych::SyntaxError) { RubyNative.load_config }
      assert_match(/ruby_native\.yml/, error.message)
    end
  end

  def test_duplicate_tab_keys_are_warned_about
    log = with_captured_log do
      with_config(app: {}, tabs: [
        {title: "Home", key: "home", path: "/"},
        {title: "Casa", key: "home", path: "/casa"}
      ]) do
        RubyNative.load_config
      end
    end
    assert_includes log, "Duplicate tab key(s)"
    assert_includes log, "home"
  end

  def test_unique_tab_keys_are_not_warned_about
    log = with_captured_log do
      with_config(app: {}, tabs: [
        {title: "Home", key: "home", path: "/"},
        {title: "Profile", key: "profile", path: "/profile"}
      ]) do
        RubyNative.load_config
      end
    end
    refute_includes log, "Duplicate tab key(s)"
  end

  def test_yaml_aliases_are_permitted
    with_raw_config(<<~YAML) do
      defaults: &defaults
        icon: house
      app:
        name: App
      tabs:
        - <<: *defaults
          title: Home
          path: /
    YAML
      RubyNative.load_config
      assert_equal "house", RubyNative.config[:tabs].first[:icon]
    end
  end

  private

  def with_captured_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  def with_config(config)
    with_raw_config(config.deep_stringify_keys.to_yaml) { yield }
  end

  def with_raw_config(yaml)
    path = Rails.root.join("config", "ruby_native.yml")
    original = path.read
    path.write(yaml)
    yield
  ensure
    path.write(original)
    RubyNative.load_config
  end
end
