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
end
