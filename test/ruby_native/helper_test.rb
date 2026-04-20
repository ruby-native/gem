require "test_helper"

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
  end

  def test_native_navbar_tag
    html = native_navbar_tag("Today")
    assert_includes html, 'data-native-navbar="Today"'
    assert_includes html, 'hidden'
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

  private

  def request
    @request
  end
end
