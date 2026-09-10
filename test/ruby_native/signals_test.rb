require "minitest/autorun"
require "ruby_native/signals"
require "ruby_native/version"

class SignalsTest < Minitest::Test
  def test_every_signal_is_namespaced
    RubyNative::Signals.names.each do |name|
      assert name.start_with?("data-native-"), "#{name} is not a data-native-* attribute"
    end
  end

  def test_every_signal_declares_a_version_or_an_owner
    RubyNative::Signals.all.each do |name, meta|
      assert meta["since"] || meta["owner"],
        "#{name} needs a `since` version, or `owner: shell` if the app writes it"
    end
  end

  def test_no_signal_claims_a_version_this_gem_has_not_reached
    RubyNative::Signals.all.each do |name, meta|
      next unless meta["since"]

      assert Gem::Version.new(meta["since"]) <= Gem::Version.new(RubyNative::VERSION),
        "#{name} claims #{meta["since"]}, which is newer than #{RubyNative::VERSION}"
    end
  end

  def test_every_singleton_is_a_known_signal
    RubyNative::Signals.singletons.each do |name|
      assert RubyNative::Signals.known?(name), "#{name} is a singleton but not in the vocabulary"
    end
  end

  def test_the_documented_paywall_attributes_are_known
    assert RubyNative::Signals.known?("data-native-customer-id")
    assert RubyNative::Signals.known?("data-native-success-path")
  end

  def test_known_signals
    assert RubyNative::Signals.known?("data-native-tabs")
    refute RubyNative::Signals.known?("data-native-tab")
  end

  def test_singletons_are_the_ones_read_by_query_selector
    assert RubyNative::Signals.singleton?("data-native-tabs")
    refute RubyNative::Signals.singleton?("data-native-menu-item")
  end

  def test_since_reports_the_introducing_version
    assert_equal "0.15.0", RubyNative::Signals.since("data-native-keyboard-toolbar")
  end

  def test_shell_written_signals_have_no_version
    assert_nil RubyNative::Signals.since("data-native-app")
  end

  def test_nearest_suggests_the_closest_signal
    assert_equal "data-native-tabs", RubyNative::Signals.nearest("data-native-tab")
    assert_equal "data-native-badge-tab", RubyNative::Signals.nearest("data-native-badge-tabs")
  end

  def test_nearest_gives_up_on_an_unrelated_attribute
    assert_nil RubyNative::Signals.nearest("data-native-wombat")
  end

  def test_signals_for_helper_lists_what_every_call_emits
    assert_equal ["data-native-navbar"], RubyNative::Signals.signals_for_helper("native_navbar_tag")
  end

  # native_fab_tag emits these only when passed `href:`, `click:` or `color:`,
  # so counting a call against them would report markup the view never renders.
  def test_signals_for_helper_leaves_out_the_conditional_ones
    signals = RubyNative::Signals.signals_for_helper("native_fab_tag")

    assert_includes signals, "data-native-fab"
    refute_includes signals, "data-native-color"
    refute_includes signals, "data-native-href"
  end

  def test_signals_for_helper_is_empty_for_an_unknown_helper
    assert_empty RubyNative::Signals.signals_for_helper("native_wombat_tag")
  end

  def test_every_always_signal_names_the_helper_it_belongs_to
    orphans = RubyNative::Signals.all.select { |_name, meta| meta["always"] && meta["helper"].nil? }

    assert_empty orphans.keys, "`always` only means anything alongside `helper`"
  end
end
