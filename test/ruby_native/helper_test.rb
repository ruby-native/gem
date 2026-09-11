require "test_helper"
require "ruby_native/signals"

class RubyNative::HelperTest < ActionView::TestCase
  include RubyNative::Helper

  def test_native_tabs_tag
    html = native_tabs_tag
    assert_includes html, 'data-native-tabs'
    assert_includes html, 'hidden'
  end

  def test_native_tabs_tag_enabled_false
    html = native_tabs_tag(enabled: false)
    assert_equal "", html
  end

  def test_native_identity_tag_signed_in
    html = native_identity_tag(42)
    assert_match(/data-native-identity="\h{16}"/, html)
    assert_includes html, 'hidden'
  end

  def test_native_identity_tag_signed_out
    html = native_identity_tag(nil)
    assert_includes html, 'data-native-identity=""'
  end

  def test_native_identity_token_is_stable
    assert_equal native_identity_token(42), native_identity_token(42)
  end

  def test_native_identity_token_differs_by_value
    refute_equal native_identity_token(42), native_identity_token(77)
  end

  def test_native_identity_token_array_defines_the_boundary
    refute_equal native_identity_token([1, 2]), native_identity_token(1)
    assert_equal native_identity_token([1, nil]), native_identity_token(1)
    assert_equal "", native_identity_token([nil])
  end

  def test_native_identity_token_is_keyed_not_a_bare_digest
    refute_equal OpenSSL::Digest::SHA256.hexdigest("42")[0, 16], native_identity_token(42)
  end

  def test_native_form_tag
    html = native_form_tag
    assert_includes html, 'data-native-form'
    assert_includes html, 'hidden'
  end

  def test_native_push_tag
    html = native_push_tag
    assert_includes html, 'data-native-push'
    assert_includes html, 'hidden'
  end

  def test_native_presentation_tag
    html = native_presentation_tag :root
    assert_includes html, 'data-native-presentation="root"'
    assert_includes html, 'hidden'
  end

  def test_native_presentation_tag_accepts_a_string
    assert_includes native_presentation_tag("root"), 'data-native-presentation="root"'
  end

  # The header is the half Advanced Mode reads, and it has to be set before the
  # response is committed or the whole approach is decided too late.
  def test_native_presentation_tag_sets_the_response_header
    native_presentation_tag :root
    assert_equal "root", response.headers["Native-Presentation"]
  end

  # Raise rather than warn-and-drop, same as the menu action vocabulary: a
  # presentation the shell silently ignores lands the page in the wrong place
  # with nothing on screen to explain why.
  def test_native_presentation_tag_rejects_an_unknown_intent
    error = assert_raises(ArgumentError) { native_presentation_tag :modal }
    assert_includes error.message, ":root"
    assert_includes error.message, '"modal"'
  end

  def test_native_back_button_tag
    html = native_back_button_tag
    assert_includes html, "<button"
    assert_includes html, "<svg"
    assert_includes html, 'class="native-back-button"'
    assert_includes html, "RubyNative.postMessage({action: &#39;back&#39;})"
  end

  def test_native_back_button_tag_custom_text
    html = native_back_button_tag("Go back")
    assert_includes html, ">Go back</button>"
  end

  def test_native_back_button_tag_merges_classes
    html = native_back_button_tag(class: "btn")
    assert_includes html, 'class="btn native-back-button"'
  end

  def test_native_back_button_tag_additional_options
    html = native_back_button_tag(id: "back-btn", data: { turbo: false })
    assert_includes html, 'id="back-btn"'
    assert_includes html, 'data-turbo="false"'
    assert_includes html, 'class="native-back-button"'
  end

  def test_native_scan_button_tag_default_label
    html = native_scan_button_tag
    assert_includes html, "<button"
    assert_includes html, ">Scan</button>"
    assert_includes html, "window.RubyNative?.scan({})"
  end

  def test_native_scan_button_tag_custom_label
    html = native_scan_button_tag("Scan ISBN")
    assert_includes html, ">Scan ISBN</button>"
  end

  # Without an explicit type a <button> submits the form it sits in, which is
  # exactly where the documented usage puts it. The scan result arrives async,
  # so the page would navigate away before it lands.
  def test_native_scan_button_tag_does_not_submit_its_form
    html = native_scan_button_tag("Scan", target: "#isbn")
    assert_includes html, 'type="button"'
  end

  def test_native_scan_button_tag_type_can_be_overridden
    html = native_scan_button_tag("Scan", type: "submit")
    assert_includes html, 'type="submit"'
    refute_includes html, 'type="button"'
  end

  def test_native_scan_button_tag_target
    html = native_scan_button_tag("Scan", target: "#isbn")
    assert_includes html, "window.RubyNative?.scan("
    assert_includes html, "target"
    assert_includes html, "#isbn"
  end

  def test_native_scan_button_tag_event_and_submit
    html = native_scan_button_tag("Scan", event: "scanned", submit: true)
    assert_includes html, "scanned"
    assert_includes html, "submit"
    assert_includes html, "true"
  end

  def test_native_scan_button_tag_formats_string_splits
    html = native_scan_button_tag("Scan", target: "#isbn", formats: "ean13, upce")
    assert_includes html, "ean13"
    assert_includes html, "upce"
  end

  def test_native_scan_button_tag_formats_array
    html = native_scan_button_tag("Scan", formats: %w[qr code128])
    assert_includes html, "qr"
    assert_includes html, "code128"
  end

  def test_native_scan_button_tag_merges_options
    html = native_scan_button_tag("Scan", class: "btn", id: "scan-btn")
    assert_includes html, 'class="btn"'
    assert_includes html, 'id="scan-btn"'
  end

  def test_native_badge_tag_with_count
    html = native_badge_tag(5)
    assert_includes html, 'data-native-badge'
    assert_includes html, 'data-native-badge-home="5"'
    assert_includes html, 'data-native-badge-tab="5"'
    assert_includes html, 'hidden'
  end

  def test_native_badge_tag_with_independent_values
    html = native_badge_tag(home: 2, tab: 3)
    assert_includes html, 'data-native-badge-home="2"'
    assert_includes html, 'data-native-badge-tab="3"'
  end

  def test_native_badge_tag_home_only
    html = native_badge_tag(home: 2)
    assert_includes html, 'data-native-badge-home="2"'
    refute_includes html, 'data-native-badge-tab'
  end

  def test_native_badge_tag_tab_only
    html = native_badge_tag(tab: 3)
    refute_includes html, 'data-native-badge-home'
    assert_includes html, 'data-native-badge-tab="3"'
  end

  def test_native_badge_tag_zero_clears_both
    html = native_badge_tag(0)
    assert_includes html, 'data-native-badge-home="0"'
    assert_includes html, 'data-native-badge-tab="0"'
  end

  def test_native_fab_tag_with_href
    html = native_fab_tag(icon: "square.and.pencil", href: "/compose")
    assert_includes html, 'data-native-fab'
    assert_includes html, 'data-native-icon="square.and.pencil"'
    assert_includes html, 'data-native-href="/compose"'
    refute_includes html, 'data-native-click'
    assert_includes html, 'hidden'
  end

  def test_native_fab_tag_with_click
    html = native_fab_tag(icon: "plus", click: "#new-button")
    assert_includes html, 'data-native-fab'
    assert_includes html, 'data-native-icon="plus"'
    assert_includes html, 'data-native-click="#new-button"'
    refute_includes html, 'data-native-href'
  end

  def test_native_fab_tag_icon_only
    html = native_fab_tag(icon: "star")
    assert_includes html, 'data-native-icon="star"'
    refute_includes html, 'data-native-href'
    refute_includes html, 'data-native-click'
    refute_includes html, 'data-native-color'
  end

  def test_native_fab_tag_with_color
    html = native_fab_tag(icon: "plus", color: "#D97706")
    assert_includes html, 'data-native-color="#D97706"'
  end

  def test_native_fab_tag_with_tint_color
    html = native_fab_tag(icon: "plus", color: :tint)
    assert_includes html, 'data-native-color="tint"'
  end

  def test_native_fab_tag_requires_icon
    assert_raises(ArgumentError) { native_fab_tag }
  end

  def test_native_menu_tag
    html = native_menu_tag(anchor: "#status-pill") do |menu|
      menu.item "Currently reading", click: "#status-reading"
      menu.item "Finished", click: "#status-finished"
    end

    assert_includes html, 'data-native-menu=""'
    assert_includes html, 'data-native-anchor="#status-pill"'
    assert_includes html, "hidden"
    assert_includes html, 'data-native-menu-item'
    assert_includes html, 'data-native-title="Currently reading"'
    assert_includes html, 'data-native-click="#status-reading"'
    assert_includes html, 'data-native-title="Finished"'
    assert_includes html, 'data-native-click="#status-finished"'
  end

  # The items are read out of the menu element by the JS bridge, so they have to
  # be nested inside it, not siblings of it.
  def test_native_menu_tag_nests_items
    html = native_menu_tag(anchor: ".menu-anchor") do |menu|
      menu.item "Edit", href: "/edit"
    end

    assert_match(/data-native-menu="".*data-native-menu-item.*<\/div>\z/m, html)
  end

  def test_native_menu_tag_item_options
    html = native_menu_tag(anchor: "#anchor") do |menu|
      menu.item "All", href: "/all", icon: "list.bullet", selected: true, action: :replace
      menu.item "Delete", click: "#delete", destructive: true
    end

    assert_includes html, 'data-native-href="/all"'
    assert_includes html, 'data-native-icon="list.bullet"'
    assert_includes html, 'data-native-selected'
    assert_includes html, 'data-native-action="replace"'
    assert_includes html, 'data-native-destructive'
  end

  def test_native_menu_tag_without_a_block
    html = native_menu_tag(anchor: "#anchor")

    assert_includes html, 'data-native-anchor="#anchor"'
    refute_includes html, 'data-native-menu-item'
    refute_includes html, "data-native-title"
  end

  def test_native_menu_tag_requires_anchor
    assert_raises(ArgumentError) { native_menu_tag(anchor: nil) }
    assert_raises(ArgumentError) { native_menu_tag(anchor: "  ") }
  end

  def test_resolve_icon_prefers_platform_specific
    resolved = RubyNative::Helper.resolve_icon(
      icon: "cup.and.saucer",
      icons: { ios: "cup.and.saucer", android: "coffee" },
      platform: "android"
    )
    assert_equal "coffee", resolved
  end

  def test_resolve_icon_falls_back_to_icon_when_platform_missing
    resolved = RubyNative::Helper.resolve_icon(
      icon: "star",
      icons: { ios: "star.fill" },
      platform: "android"
    )
    assert_equal "star", resolved
  end

  def test_resolve_icon_returns_nil_when_nothing_set
    assert_nil RubyNative::Helper.resolve_icon(icon: nil, icons: nil, platform: "android")
  end

  def test_resolve_icon_accepts_string_keys
    resolved = RubyNative::Helper.resolve_icon(
      icon: nil,
      icons: { "android" => "coffee" },
      platform: "android"
    )
    assert_equal "coffee", resolved
  end

  def test_resolve_icon_without_platform_returns_fallback
    resolved = RubyNative::Helper.resolve_icon(
      icon: "cup.and.saucer",
      icons: { ios: "cup.and.saucer", android: "coffee" },
      platform: nil
    )
    assert_equal "cup.and.saucer", resolved
  end

  # `icons: [ios: "...", android: "..."]` in ERB is an Array holding one Hash.
  # It used to skip the lookup and fall back to a nil `icon:`, rendering nothing
  # on either platform without a word about why.
  def test_resolve_icon_raises_on_array_instead_of_hash
    error = assert_raises(ArgumentError) do
      RubyNative::Helper.resolve_icon(
        icons: [ { ios: "ellipsis.circle", android: "more_horiz" } ],
        platform: "android"
      )
    end
    assert_match(/must be a Hash/, error.message)
    assert_match(/square brackets/, error.message)
  end

  def test_resolve_icon_raises_on_string_instead_of_hash
    assert_raises(ArgumentError) do
      RubyNative::Helper.resolve_icon(icons: "more_horiz", platform: "android")
    end
  end

  # The raise is about the shape of `icons:`, not whether a platform is known,
  # so it fires on the web too rather than only inside the app.
  def test_resolve_icon_raises_without_platform
    assert_raises(ArgumentError) do
      RubyNative::Helper.resolve_icon(icon: "gear", icons: [ { ios: "gear" } ], platform: nil)
    end
  end

  def test_resolve_icon_allows_nil_icons
    assert_equal "gear", RubyNative::Helper.resolve_icon(icon: "gear", icons: nil, platform: "ios")
  end

  # A browser has no platform, so `icons:` alone has to resolve to something.
  # Returning nil would make native_fab_tag raise on a page that is fine in the
  # app. Matches how backfill_tab_icons fills a tab's flat icon.
  def test_resolve_icon_without_platform_falls_back_to_ios_then_android
    assert_equal "plus", RubyNative::Helper.resolve_icon(
      icons: { ios: "plus", android: "add" }, platform: nil
    )
    assert_equal "add", RubyNative::Helper.resolve_icon(
      icons: { android: "add" }, platform: nil
    )
  end

  def test_native_fab_tag_accepts_icons_without_icon_on_web
    html = native_fab_tag(icons: { ios: "plus", android: "add" }, href: "/posts/new")
    assert_includes html, 'data-native-icon="plus"'
  end

  def test_native_fab_tag_still_requires_some_icon
    assert_raises(ArgumentError) { native_fab_tag(icons: {}) }
  end

  def test_native_navbar_tag
    html = native_navbar_tag("Today")
    assert_includes html, 'data-native-navbar="Today"'
    assert_includes html, 'hidden'
  end

  def test_native_navbar_tag_pull_to_refresh_default
    html = native_navbar_tag("Today")
    refute_includes html, "data-native-pull-to-refresh"
  end

  def test_native_navbar_tag_pull_to_refresh_disabled
    html = native_navbar_tag("Today", pull_to_refresh: false)
    assert_includes html, 'data-native-pull-to-refresh="false"'
  end

  def test_native_navbar_tag_without_title
    html = native_navbar_tag
    assert_includes html, 'data-native-navbar=""'
    assert_includes html, 'hidden'
  end

  def test_native_navbar_tag_without_title_with_buttons
    html = native_navbar_tag do |navbar|
      navbar.button "Sign out", icon: "rectangle.portrait.and.arrow.forward", click: "#sign-out-button"
    end

    assert_includes html, 'data-native-navbar=""'
    assert_includes html, 'data-native-button'
    assert_includes html, 'data-native-title="Sign out"'
    assert_includes html, 'data-native-icon="rectangle.portrait.and.arrow.forward"'
    assert_includes html, 'data-native-click="#sign-out-button"'
  end

  def test_native_navbar_tag_button_positional_title
    html = native_navbar_tag("Page") do |navbar|
      navbar.button "Add", href: "/add"
    end

    assert_includes html, 'data-native-title="Add"'
    assert_includes html, 'data-native-href="/add"'
  end

  def test_native_navbar_tag_button_positional_title_and_icon
    html = native_navbar_tag("Page") do |navbar|
      navbar.button "Sign out", icon: "rectangle.portrait.and.arrow.forward", click: "#sign-out-button"
    end

    assert_includes html, 'data-native-title="Sign out"'
    assert_includes html, 'data-native-icon="rectangle.portrait.and.arrow.forward"'
    assert_includes html, 'data-native-click="#sign-out-button"'
  end

  def test_native_navbar_tag_button_positional_title_with_menu
    html = native_navbar_tag("Profile") do |navbar|
      navbar.button "More", icon: "ellipsis.circle" do |button|
        button.item "Edit", href: "/edit"
        button.item "Delete", click: "#delete", icon: "trash"
      end
    end

    assert_includes html, 'data-native-title="More"'
    assert_includes html, 'data-native-icon="ellipsis.circle"'
    assert_includes html, 'data-native-menu-item'
    assert_includes html, 'data-native-title="Edit"'
    assert_includes html, 'data-native-title="Delete"'
  end

  def test_native_navbar_tag_with_button
    html = native_navbar_tag("Habits") do |navbar|
      navbar.button icon: "plus", href: "/habits/new"
    end

    assert_includes html, 'data-native-navbar="Habits"'
    assert_includes html, 'data-native-button'
    assert_includes html, 'data-native-icon="plus"'
    assert_includes html, 'data-native-href="/habits/new"'
    assert_includes html, 'data-native-position="trailing"'
  end

  def test_native_navbar_tag_button_with_title
    html = native_navbar_tag("Page") do |navbar|
      navbar.button "Add", href: "/add"
    end

    assert_includes html, 'data-native-title="Add"'
    refute_includes html, 'data-native-icon'
  end

  def test_native_navbar_tag_button_leading_position
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "gear", position: :leading
    end

    assert_includes html, 'data-native-position="leading"'
  end

  def test_native_navbar_tag_button_with_click
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "ellipsis.circle", click: "#my-button"
    end

    assert_includes html, 'data-native-click="#my-button"'
    refute_includes html, 'data-native-href'
  end

  def test_native_navbar_tag_button_selected
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "star", selected: true
    end

    assert_includes html, 'data-native-selected'
  end

  def test_native_navbar_tag_share_button
    html = native_navbar_tag("Article") do |navbar|
      navbar.share_button
    end

    assert_includes html, "data-native-button"
    assert_includes html, "data-native-share"
    assert_includes html, 'data-native-icon="square.and.arrow.up"'
    assert_includes html, 'data-native-title="Share"'
    assert_includes html, 'data-native-position="trailing"'
    refute_includes html, "data-native-share-url"
  end

  def test_native_navbar_tag_share_button_defaults_to_material_share_on_android
    define_singleton_method(:native_platform) { "android" }

    html = native_navbar_tag("Article") do |navbar|
      navbar.share_button
    end

    assert_includes html, 'data-native-icon="share"'
  end

  def test_native_navbar_tag_share_item_defaults_to_material_share_on_android
    define_singleton_method(:native_platform) { "android" }

    html = native_navbar_tag("Article") do |navbar|
      navbar.button icon: "ellipsis.circle" do |button|
        button.share_item
      end
    end

    assert_includes html, 'data-native-icon="share"'
  end

  def test_native_navbar_tag_share_button_with_url_and_icon
    html = native_navbar_tag("Article") do |navbar|
      navbar.share_button url: "https://example.com/articles/1", icon: "square.and.arrow.up.circle", title: "Send"
    end

    assert_includes html, 'data-native-share-url="https://example.com/articles/1"'
    assert_includes html, 'data-native-icon="square.and.arrow.up.circle"'
    assert_includes html, 'data-native-title="Send"'
    refute_includes html, "data-native-share-color"
  end

  def test_native_navbar_tag_share_item_in_menu
    html = native_navbar_tag("Article") do |navbar|
      navbar.button icon: "ellipsis.circle" do |button|
        button.share_item
      end
    end

    assert_includes html, "data-native-menu-item"
    assert_includes html, "data-native-share"
    assert_includes html, 'data-native-title="Share"'
    assert_includes html, 'data-native-icon="square.and.arrow.up"'
  end

  def test_native_navbar_tag_button_with_menu_items
    html = native_navbar_tag("Profile") do |navbar|
      navbar.button icon: "ellipsis.circle", position: :leading do |button|
        button.item "Edit profile", href: "/profile/edit", icon: "pencil"
        button.item "Sign out", click: "#sign-out-button", icon: "rectangle.portrait.and.arrow.right"
      end
    end

    assert_includes html, 'data-native-navbar="Profile"'
    assert_includes html, 'data-native-button'
    assert_includes html, 'data-native-menu-item'
    assert_includes html, 'data-native-title="Edit profile"'
    assert_includes html, 'data-native-href="/profile/edit"'
    assert_includes html, 'data-native-icon="pencil"'
    assert_includes html, 'data-native-title="Sign out"'
    assert_includes html, 'data-native-click="#sign-out-button"'
  end

  def test_native_navbar_tag_menu_item_selected
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "line.3.horizontal.decrease" do |button|
        button.item "All", href: "/all", selected: true
        button.item "Active", href: "/active"
      end
    end

    assert_match(/data-native-href="\/all".*data-native-selected/, html)
    refute_match(/data-native-href="\/active".*data-native-selected/, html)
  end

  def test_native_navbar_tag_multiple_buttons
    html = native_navbar_tag("Habits") do |navbar|
      navbar.button icon: "person", position: :leading, href: "/profile"
      navbar.button icon: "plus", href: "/habits/new"
    end

    assert_includes html, 'data-native-position="leading"'
    assert_includes html, 'data-native-icon="person"'
    assert_includes html, 'data-native-href="/profile"'
    assert_includes html, 'data-native-position="trailing"'
    assert_includes html, 'data-native-icon="plus"'
    assert_includes html, 'data-native-href="/habits/new"'
  end

  def test_native_navbar_tag_submit_button_with_regular_button
    html = native_navbar_tag("Edit") do |navbar|
      navbar.button icon: "trash", click: "#delete-button"
      navbar.submit_button title: "Save"
    end

    assert_includes html, 'data-native-icon="trash"'
    assert_includes html, 'data-native-click="#delete-button"'
    assert_includes html, 'data-native-submit-button'
    assert_includes html, 'data-native-title="Save"'
  end

  def test_native_navbar_tag_empty_block
    html = native_navbar_tag("Page") { |_| }

    assert_includes html, 'data-native-navbar="Page"'
    assert_includes html, 'hidden'
    refute_includes html, 'data-native-button'
    refute_includes html, 'data-native-submit-button'
  end

  def test_native_navbar_tag_menu_item_click
    html = native_navbar_tag("Account") do |navbar|
      navbar.button icon: "ellipsis.circle", position: :leading do |button|
        button.item "Edit profile", click: "#edit-profile-link", icon: "pencil"
        button.item "Sign out", click: "#sign-out-button", icon: "rectangle.portrait.and.arrow.right"
      end
    end

    assert_includes html, 'data-native-click="#edit-profile-link"'
    assert_includes html, 'data-native-click="#sign-out-button"'
  end

  def test_native_navbar_tag_menu_item_href
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "gear" do |button|
        button.item "Settings", href: "/settings"
      end
    end

    assert_includes html, 'data-native-href="/settings"'
    refute_includes html, 'data-native-click'
  end

  def test_native_navbar_tag_menu_item_action
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "gear" do |button|
        button.item "Settings", href: "/settings", action: :replace
      end
    end

    assert_includes html, 'data-native-href="/settings"'
    assert_includes html, 'data-native-action="replace"'
  end

  def test_native_navbar_tag_menu_item_omits_action_by_default
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "gear" do |button|
        button.item "Settings", href: "/settings"
      end
    end

    refute_includes html, "data-native-action"
  end

  def test_native_navbar_tag_menu_item_rejects_unknown_action
    assert_raises(ArgumentError) do
      native_navbar_tag("Page") do |navbar|
        navbar.button icon: "gear" do |button|
          button.item "Settings", href: "/settings", action: :pop
        end
      end
    end
  end

  def test_native_navbar_tag_submit_button
    html = native_navbar_tag("Edit habit") do |navbar|
      navbar.submit_button title: "Save"
    end

    assert_includes html, 'data-native-navbar="Edit habit"'
    assert_includes html, 'data-native-submit-button'
    assert_includes html, 'data-native-title="Save"'
    assert_includes html, "data-native-click"
  end

  def test_native_navbar_tag_submit_button_defaults
    html = native_navbar_tag("Page") do |navbar|
      navbar.submit_button
    end

    assert_includes html, 'data-native-title="Save"'
    assert_includes html, "data-native-click"
  end

  def test_native_navbar_tag_submit_button_custom_click
    html = native_navbar_tag("Page") do |navbar|
      navbar.submit_button title: "Create", click: "#my-submit"
    end

    assert_includes html, 'data-native-title="Create"'
    assert_includes html, 'data-native-click="#my-submit"'
  end

  def test_native_navbar_tag_with_segments
    html = native_navbar_tag do |navbar|
      navbar.segment "Pledges", href: "/pledges", selected: true
      navbar.segment "Rewards", href: "/rewards"
    end

    assert_includes html, "data-native-navbar"
    assert_includes html, "hidden"
    assert_includes html, "data-native-segment"
    assert_includes html, 'data-native-title="Pledges"'
    assert_includes html, 'data-native-href="/pledges"'
    assert_includes html, 'data-native-title="Rewards"'
    assert_includes html, 'data-native-href="/rewards"'
  end

  def test_native_navbar_tag_segment_selected
    html = native_navbar_tag do |navbar|
      navbar.segment "Pledges", href: "/pledges", selected: true
      navbar.segment "Rewards", href: "/rewards"
    end

    assert_match(/data-native-href="\/pledges".*data-native-selected/, html)
    refute_match(/data-native-href="\/rewards".*data-native-selected/, html)
  end

  def test_native_navbar_tag_segment_with_click
    html = native_navbar_tag do |navbar|
      navbar.segment "Active", click: "#active-segment"
    end

    assert_includes html, "data-native-segment"
    assert_includes html, 'data-native-click="#active-segment"'
    refute_includes html, "data-native-href"
  end

  # Builder methods return a blank, html-safe string so they read naturally with
  # `<%= navbar.button %>` in ERB (which erb_lint requires) without emitting
  # anything. The nav bar still renders from the collected items.
  def test_navbar_builder_methods_are_output_safe
    builder = RubyNative::Helper::NavbarBuilder.new(self)

    result = builder.button("Add", href: "/add")

    assert_equal "", result
    assert_predicate result, :html_safe?
    assert_includes builder.to_html, 'data-native-title="Add"'
  end

  def test_navbar_menu_builder_items_are_output_safe
    builder = RubyNative::Helper::NavbarMenuBuilder.new(self)

    result = builder.item("Edit", href: "/edit")

    assert_equal "", result
    assert_predicate result, :html_safe?
    assert_includes builder.to_html, 'data-native-title="Edit"'
  end

  def test_native_keyboard_tag_hides_the_toolbar_by_default
    html = native_keyboard_tag
    assert_includes html, 'data-native-keyboard-toolbar="false"'
    assert_includes html, "hidden"
  end

  def test_native_keyboard_tag_renders_nothing_when_the_toolbar_is_kept
    assert_equal "", native_keyboard_tag(toolbar: true)
  end

  def test_native_haptic_data_defaults_to_success
    data = native_haptic_data
    assert_equal "success", data[:native_haptic]
  end

  def test_native_haptic_data_with_symbol_feedback
    data = native_haptic_data(:error)
    assert_equal "error", data[:native_haptic]
  end

  def test_native_haptic_data_with_string_feedback
    data = native_haptic_data("warning")
    assert_equal "warning", data[:native_haptic]
  end

  def test_native_haptic_data_nil_defaults_to_success
    data = native_haptic_data(nil)
    assert_equal "success", data[:native_haptic]
  end

  def test_native_haptic_data_blank_defaults_to_success
    data = native_haptic_data("")
    assert_equal "success", data[:native_haptic]
  end

  def test_native_haptic_data_preserves_other_data_keys
    data = native_haptic_data(:success, turbo_method: :delete, id: "btn")
    assert_equal :delete, data[:turbo_method]
    assert_equal "btn", data[:id]
    assert_equal "success", data[:native_haptic]
  end

  def test_native_review_tag
    html = native_review_tag
    assert_includes html, 'data-native-review'
    assert_includes html, 'hidden'
  end

  def test_native_toast_tag_defaults
    html = native_toast_tag("Saved.")
    assert_includes html, 'data-native-toast'
    assert_includes html, 'data-native-toast-message="Saved."'
    assert_includes html, 'data-native-toast-icon="checkmark.circle.fill"'
    assert_includes html, 'data-native-toast-duration="4"'
    assert_includes html, 'data-native-toast-appearance="inverted"'
    assert_includes html, 'hidden'
  end

  def test_native_toast_tag_blank_message_renders_nothing
    assert_equal "", native_toast_tag(nil)
    assert_equal "", native_toast_tag("")
  end

  def test_native_toast_tag_default_icon_on_android
    define_singleton_method(:native_platform) { "android" }

    html = native_toast_tag("Saved.")
    assert_includes html, 'data-native-toast-icon="check_circle"'
  end

  def test_native_toast_tag_default_icon_on_ios
    define_singleton_method(:native_platform) { "ios" }

    html = native_toast_tag("Saved.")
    assert_includes html, 'data-native-toast-icon="checkmark.circle.fill"'
  end

  def test_native_toast_tag_resolves_icons_per_platform
    define_singleton_method(:native_platform) { "android" }

    html = native_toast_tag("Muted.", icons: { ios: "bell.slash.fill", android: "notifications_off" })
    assert_includes html, 'data-native-toast-icon="notifications_off"'
  end

  def test_native_toast_tag_with_flat_icon
    html = native_toast_tag("Muted.", icon: "bell.slash.fill")
    assert_includes html, 'data-native-toast-icon="bell.slash.fill"'
  end

  def test_native_toast_tag_icon_false_emits_explicit_none
    html = native_toast_tag("Saved.", icon: false)
    assert_includes html, 'data-native-toast-icon=""'
    refute_includes html, 'checkmark'
  end

  def test_native_toast_tag_with_duration
    html = native_toast_tag("Saved.", duration: 6)
    assert_includes html, 'data-native-toast-duration="6"'
  end

  def test_native_toast_tag_with_system_appearance
    html = native_toast_tag("Saved.", appearance: :system)
    assert_includes html, 'data-native-toast-appearance="system"'
  end

  def test_native_toast_tag_rejects_unknown_appearance
    error = assert_raises(ArgumentError) { native_toast_tag("Saved.", appearance: :neon) }
    assert_includes error.message, ":inverted or :system"
  end

  # `ruby_native check` counts a helper call against every signal marked
  # `always` in config/signals.yml, so a helper that stops emitting one turns
  # into a warning about markup the view never renders. These render each
  # helper and hold the metadata to what the code actually does.
  ALWAYS_INVOCATIONS = {
    "native_badge_tag" => -> { native_badge_tag(3) },
    "native_fab_tag" => -> { native_fab_tag(icon: "plus") },
    "native_form_tag" => -> { native_form_tag },
    "native_haptic_data" => -> { native_haptic_data },
    "native_identity_tag" => -> { native_identity_tag(42) },
    "native_menu_tag" => -> { native_menu_tag(anchor: "#profile") },
    "native_navbar_tag" => -> { native_navbar_tag("Orders") },
    "native_overscroll_tag" => -> { native_overscroll_tag(top: "#ffffff") },
    "native_presentation_tag" => -> { native_presentation_tag(:root) },
    "native_push_tag" => -> { native_push_tag },
    "native_review_tag" => -> { native_review_tag }
  }.freeze

  def test_every_always_signal_is_emitted_by_a_bare_call_to_its_helper
    RubyNative::Signals.helper_signals.each do |helper, signals|
      invocation = ALWAYS_INVOCATIONS[helper]
      refute_nil invocation, "#{helper} is marked `always` in signals.yml but has no invocation here"

      emitted = attributes_in(instance_exec(&invocation))

      signals.each do |signal|
        assert_includes emitted, signal,
          "signals.yml marks #{signal} as always, but #{helper} did not emit it"
      end
    end
  end

  # A helper that can render nothing cannot be `always`: check would count the
  # call against a signal that never reaches the page.
  def test_a_helper_that_can_render_nothing_is_not_marked_always
    assert_equal "", native_tabs_tag(enabled: false)
    assert_equal "", native_keyboard_tag(toolbar: true)
    assert_equal "", native_toast_tag("")

    %w[native_tabs_tag native_keyboard_tag native_toast_tag].each do |helper|
      assert_empty RubyNative::Signals.signals_for_helper(helper),
        "#{helper} can render nothing, so no signal of its should be marked `always`"
    end
  end

  private

  # native_haptic_data returns the data hash itself rather than an element.
  def attributes_in(rendered)
    return rendered.keys.map { |key| "data-#{key.to_s.tr("_", "-")}" } if rendered.is_a?(Hash)

    rendered.to_s.scan(/data-native-[a-z-]+/)
  end

  def request
    @request
  end
end
