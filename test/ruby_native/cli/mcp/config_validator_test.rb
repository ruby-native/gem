require "minitest/autorun"
require "erb"
require "fileutils"
require "tmpdir"
require "ruby_native/cli/mcp/config_validator"

class ConfigValidatorTest < Minitest::Test
  def test_the_generated_config_passes
    assert_empty validate(<<~YAML)
      app:
        mode: normal
      appearance:
        tint_color: "#007AFF"
        background_color: "#FFFFFF"
      tabs:
        - title: Home
          path: /
          icon: house
        - title: Profile
          path: /profile
          icon: person
    YAML
  end

  # The first thing a new app should see is its own config, not a report on a
  # file it has not touched yet.
  def test_the_file_the_install_generator_writes_passes
    template = File.expand_path("../../../../lib/generators/ruby_native/templates/ruby_native.yml", __dir__)
    @tabs = [ { title: "Home", path: "/", icon: "house" }, { title: "Profile", path: "/profile", icon: "person" } ]
    written = ERB.new(File.read(template), trim_mode: "-").result(binding)

    assert_empty validate(written)
  end

  def test_a_missing_file_says_how_to_make_one
    offense = in_app { RubyNative::CLI::Mcp::ConfigValidator.run.first }

    assert_equal :error, offense.severity
    assert_match "rails generate ruby_native:install", offense.message
  end

  def test_invalid_yaml_is_an_error_on_its_line
    offense = validate(<<~YAML).first
      tabs:
        - title: Home
         path: /
    YAML

    assert_equal :error, offense.severity
    assert_equal 3, offense.line
    assert_match "not valid YAML", offense.message
  end

  # libyaml reports where it gave up, which for some mistakes is past the end
  # of the file. The report still has to land on a line that exists.
  def test_a_syntax_error_reported_past_the_end_lands_on_a_real_line
    offense = validate("\tbad: tab indent\n").first

    assert_equal 1, offense.line
  end

  def test_an_empty_file_says_the_app_boots_unconfigured
    offense = validate("# nothing but a comment\n").first

    assert_equal :error, offense.severity
    assert_match "boots unconfigured", offense.message
  end

  # --- Top level ---

  def test_an_unknown_top_level_key_lists_the_real_ones
    offense = validate("apperance:\n  tint_color: \"#007AFF\"\n").first

    assert_equal :warning, offense.severity
    assert_equal 1, offense.line
    assert_match "Unknown top-level key `apperance`", offense.message
    assert_match "appearance", offense.message
  end

  # --- app ---

  def test_an_unrecognized_mode_is_a_warning_because_the_app_falls_back
    offense = validate("app:\n  mode: advnaced\n").first

    assert_equal :warning, offense.severity
    assert_match "runs Normal Mode", offense.message
  end

  def test_a_relative_entry_path_suggests_the_absolute_one
    assert_match %(write it absolute: "/inbox"), validate("app:\n  mode: normal\n  entry_path: inbox\n").first.message
  end

  # --- appearance ---

  # UIColor(hex:) takes exactly six hex digits, so a three-digit shorthand is
  # read as no color at all and the app quietly uses its default.
  def test_a_three_digit_hex_color_is_a_warning
    offense = validate("appearance:\n  tint_color: \"#FFF\"\n").first

    assert_equal :warning, offense.severity
    assert_match "not a six-digit hex color", offense.message
  end

  def test_a_per_theme_color_checks_both_sides
    offenses = validate(<<~YAML)
      appearance:
        tint_color:
          light: "#007AFF"
          dark: nope
    YAML

    assert_equal 1, offenses.size
    assert_equal "appearance.tint_color.dark", offenses.first.key
  end

  def test_a_per_theme_color_missing_a_side_fails_the_decode
    offense = validate("appearance:\n  tint_color:\n    light: \"#007AFF\"\n").first

    assert_equal :error, offense.severity
    assert_match "needs both", offense.message
  end

  def test_an_unknown_theme_is_an_error
    offense = validate("appearance:\n  theme: sytem\n").first

    assert_equal :error, offense.severity
    assert_match "auto, light, dark", offense.message
  end

  def test_a_non_boolean_landscape_is_an_error
    assert_equal :error, validate("appearance:\n  landscape: \"yes\"\n").first.severity
  end

  def test_an_unknown_status_bar_style_is_an_error
    offense = validate("appearance:\n  navbar:\n    status_bar: auto\n").first

    assert_equal "appearance.navbar.status_bar", offense.key
    assert_equal :error, offense.severity
  end

  def test_an_unknown_appearance_key_is_a_warning
    assert_match "Unknown key `tintColor`", validate("appearance:\n  tintColor: \"#007AFF\"\n").first.message
  end

  # --- tabs ---

  def test_a_tab_without_an_icon_fails_the_whole_config
    offense = validate(<<~YAML).first
      tabs:
        - title: Home
          path: /
    YAML

    assert_equal :error, offense.severity
    assert_equal "tabs[0].icon", offense.key
    assert_equal 2, offense.line
    assert_match "error screen", offense.message
  end

  def test_per_platform_icons_satisfy_the_icon_requirement
    assert_empty validate(<<~YAML)
      tabs:
        - title: Home
          path: /
          icons:
            ios: house
            android: home
    YAML
  end

  def test_a_misspelled_icon_draws_a_placeholder_on_both_platforms
    offenses = validate("tabs:\n  - title: Home\n    path: /\n    icon: hosue\n")

    assert_equal 2, offenses.size
    assert offenses.all? { |o| o.severity == :warning && o.key == "tabs[0].icon" && o.line == 4 }
    assert_match "isn't an SF Symbol", offenses[0].message
    assert_match "isn't a Material Symbol", offenses[1].message
  end

  def test_an_sf_symbol_in_the_shared_icon_is_pointed_at_icons
    offense = sole(validate("tabs:\n  - title: Coffee\n    path: /\n    icon: cup.and.saucer\n"))

    assert_match "Android draws a placeholder", offense.message
    assert_match "`icons.ios`", offense.message
  end

  def test_a_material_symbol_in_the_ios_slot_is_named
    offense = sole(validate(<<~YAML))
      tabs:
        - title: More
          path: /
          icons:
            ios: more_horiz
            android: more_horiz
    YAML

    assert_equal "tabs[0].icons.ios", offense.key
    assert_equal 5, offense.line
    assert_match "isn't an SF Symbol", offense.message
  end

  def test_a_symbol_newer_than_the_ios_floor_is_a_warning
    offense = sole(validate(<<~YAML))
      tabs:
        - title: Books
          path: /
          icons:
            ios: apple.books.pages
            android: book
    YAML

    assert_match "needs iOS 26.", offense.message
    assert_match "older devices draw a placeholder", offense.message
  end

  def test_a_tab_without_a_path_fails_the_whole_config
    offense = validate("tabs:\n  - title: Home\n    icon: house\n").first

    assert_equal :error, offense.severity
    assert_equal "tabs[0].path", offense.key
  end

  def test_a_tab_without_a_title_or_a_key_renders_as_untitled
    offense = validate("tabs:\n  - path: /\n    icon: house\n").first

    assert_equal :warning, offense.severity
    assert_match "Untitled", offense.message
  end

  def test_a_keyed_tab_without_a_title_is_pointed_at_its_locale_file
    offense = validate("tabs:\n  - path: /\n    icon: house\n    key: home\n").first

    assert_match "ruby_native.tabs.home.title", offense.message
  end

  def test_two_tabs_sharing_a_key_is_a_warning
    offense = validate(<<~YAML).find { |o| o.key == "tabs" }
      tabs:
        - title: Home
          path: /
          icon: house
          key: home
        - title: House
          path: /house
          icon: house
          key: home
    YAML

    assert_equal :warning, offense.severity
    assert_match "always mislabeled", offense.message
  end

  # The app rejects `true` outright rather than reading it as "always route
  # here", so this one is a decode failure and not a no-op.
  def test_auto_route_true_is_an_error
    offense = validate(<<~YAML).first
      tabs:
        - title: Home
          path: /
          icon: house
          auto_route: true
    YAML

    assert_equal :error, offense.severity
    assert_match "rejects outright", offense.message
  end

  def test_auto_route_false_and_a_list_are_both_fine
    assert_empty validate(<<~YAML)
      tabs:
        - title: Home
          path: /
          icon: house
          auto_route: false
        - title: Orders
          path: /orders
          icon: person
          auto_route: ["/orders/"]
    YAML
  end

  def test_a_non_boolean_tab_flag_is_an_error
    offense = validate(<<~YAML).first
      tabs:
        - title: Home
          path: /
          icon: house
          badge: "true"
    YAML

    assert_equal "tabs[0].badge", offense.key
    assert_equal :error, offense.severity
  end

  def test_an_unknown_tab_key_lists_the_real_ones
    offense = validate(<<~YAML).first
      tabs:
        - title: Home
          path: /
          icon: house
          eagre: true
    YAML

    assert_match "Unknown key `eagre` under `tabs[0]`", offense.message
    assert_match "eager", offense.message
  end

  # --- auth, analytics, links ---

  def test_an_oauth_callback_path_is_a_warning
    offense = validate(<<~YAML).first
      auth:
        oauth_paths:
          - /auth/google
          - /auth/google/callback
    YAML

    assert_equal :warning, offense.severity
    assert_match "List only the authorize path", offense.message
  end

  def test_an_oauth_path_that_merely_looks_like_a_callback_is_left_alone
    assert_empty validate("auth:\n  oauth_paths:\n    - /auth/callback\n")
  end

  def test_analytics_as_a_string_is_a_warning
    offense = validate("analytics: \"false\"\n").first

    assert_equal :warning, offense.severity
    assert_match "keeps reporting", offense.message
  end

  def test_analytics_as_a_boolean_passes
    assert_empty validate("analytics: false\n")
  end

  def test_a_linked_path_with_a_trailing_star_is_a_warning
    assert_match "strips the trailing", validate("linked_paths:\n  - /pair/*\n").first.message
  end

  def test_a_relative_linked_path_is_a_warning
    assert_match %("/pair/"), validate("linked_paths:\n  - pair/\n").first.message
  end

  def test_half_configured_universal_links_name_the_endpoint
    offense = validate("ios:\n  bundle_id: com.example.app\n").first

    assert_equal :warning, offense.severity
    assert_match "team_id", offense.message
    assert_match "apple-app-site-association", offense.message
  end

  def test_fully_configured_universal_links_pass
    assert_empty validate("ios:\n  bundle_id: com.example.app\n  team_id: ABCD123456\n")
  end

  def test_android_firebase_alone_passes_without_the_app_link_keys
    assert_empty validate(<<~YAML)
      android:
        firebase:
          app_id: "1:1234567890:android:abc123"
          api_key: AIzaExample
          project_id: example
          sender_id: "1234567890"
    YAML
  end

  def test_android_firebase_missing_a_value_keeps_push_off
    offense = sole(validate("android:\n  firebase:\n    app_id: \"1:1:android:a\"\n    api_key: AIzaExample\n    project_id: example\n"))

    assert_equal :warning, offense.severity
    assert_match "`sender_id`", offense.message
    assert_match "push stays off", offense.message
  end

  def test_an_ios_app_id_under_android_firebase_is_a_warning
    offense = sole(validate("android:\n  firebase:\n    app_id: \"1:1:ios:a\"\n    api_key: k\n    project_id: p\n    sender_id: \"1\"\n"))

    assert_equal "android.firebase.app_id", offense.key
  end

  def test_half_configured_app_links_still_name_the_endpoint
    assert_match "assetlinks.json", sole(validate("android:\n  package: com.example.app\n")).message
  end

  # --- ERB ---

  # The file is rendered as ERB before Rails parses it, and a navbar logo is
  # meant to interpolate image_url. There is no Rails here to render against,
  # so a value this command cannot know must not be reported as wrong.
  def test_a_value_built_from_erb_is_not_second_guessed
    assert_empty validate(<<~YAML)
      appearance:
        navbar:
          logo: "<%= image_url("logo.png") %>"
        tint_color: "<%= @brand_color %>"
    YAML
  end

  def test_erb_that_takes_structure_with_it_says_so_instead_of_crying_syntax
    offense = validate(<<~YAML).first
      tabs:
      <% @tabs.each do |tab| %>
        - title: <%= tab.name %>
      <% end %>
    YAML

    assert_equal :warning, offense.severity
    assert_match "does not mean the file is broken", offense.message
  end

  private

  def sole(offenses)
    assert_equal 1, offenses.size, offenses.map(&:message).join("\n")
    offenses.first
  end

  def validate(yaml)
    in_app do
      FileUtils.mkdir_p("config")
      File.write("config/ruby_native.yml", yaml)

      RubyNative::CLI::Mcp::ConfigValidator.run
    end
  end

  def in_app(&block)
    Dir.mktmpdir { |dir| Dir.chdir(dir, &block) }
  end
end
