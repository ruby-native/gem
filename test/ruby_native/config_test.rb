require "test_helper"

class RubyNative::ConfigTest < Minitest::Test
  def test_load_config_reads_yaml
    RubyNative.load_config
    refute_nil RubyNative.config
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

  def test_app_name_defaults_when_app_key_missing
    with_config(appearance: {tint_color: "#007AFF"}, tabs: []) do
      RubyNative.load_config
      assert_equal "Ruby Native", RubyNative.config[:app][:name]
    end
  end

  def test_app_name_defaults_when_name_key_missing
    with_config(app: {mode: "normal"}, appearance: {tint_color: "#007AFF"}, tabs: []) do
      RubyNative.load_config
      assert_equal "Ruby Native", RubyNative.config[:app][:name]
    end
  end

  def test_app_name_not_overwritten_when_present
    with_config(app: {name: "My App"}, appearance: {tint_color: "#007AFF"}, tabs: []) do
      RubyNative.load_config
      assert_equal "My App", RubyNative.config[:app][:name]
    end
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

  private

  def with_config(config)
    path = Rails.root.join("config", "ruby_native.yml")
    original = path.read
    path.write(config.deep_stringify_keys.to_yaml)
    yield
  ensure
    path.write(original)
  end
end
