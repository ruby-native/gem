require "test_helper"

class RubyNative::HelperTest < ActionView::TestCase
  include RubyNative::Helper

  def test_native_tabs_tag
    html = native_tabs_tag
    assert_includes html, 'data-native-tabs'
    assert_includes html, 'hidden'
    assert_includes html, 'data-controller="bridge--tabs"'
    assert_includes html, 'data-bridge--tabs-enabled-value="true"'
  end

  def test_native_tabs_tag_enabled_false
    html = native_tabs_tag(enabled: false)
    refute_includes html, 'data-native-tabs'
    assert_includes html, 'data-controller="bridge--tabs"'
    assert_includes html, 'data-bridge--tabs-enabled-value="false"'
  end

  def test_native_form_tag
    html = native_form_tag
    assert_includes html, 'data-native-form'
    assert_includes html, 'hidden'
  end

  def test_native_form_data
    data = native_form_data
    assert_equal "bridge--form", data[:controller]
  end

  def test_native_form_data_merges_existing_controller
    data = native_form_data(controller: "my-controller")
    assert_equal "my-controller bridge--form", data[:controller]
  end

  def test_native_form_data_preserves_other_data_keys
    data = native_form_data(controller: "other", turbo_frame: "modal")
    assert_equal "other bridge--form", data[:controller]
    assert_equal "modal", data[:turbo_frame]
  end

  def test_native_submit_data
    data = native_submit_data
    assert_equal({ bridge__form_target: "submit" }, data)
  end

  def test_native_push_tag
    html = native_push_tag
    assert_includes html, 'data-native-push'
    assert_includes html, 'hidden'
    assert_includes html, 'data-controller="bridge--push"'
  end

  def test_native_search_tag
    html = native_search_tag
    assert_includes html, 'data-controller="bridge--search"'
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

  def test_native_button_tag
    html = native_button_tag("Add", "/links/new", ios_image: "plus", class: "btn")
    assert_includes html, 'data-controller="bridge--button"'
    assert_includes html, 'data-bridge-ios-image="plus"'
    assert_includes html, 'data-bridge-side="right"'
    assert_includes html, 'href="/links/new"'
    assert_includes html, 'class="btn"'
    assert_includes html, ">Add</a>"
  end

  def test_native_button_tag_left_side
    html = native_button_tag("Back", "/home", side: :left)
    assert_includes html, 'data-bridge-side="left"'
  end

  def test_native_button_tag_without_image
    html = native_button_tag("Add", "/links/new")
    refute_includes html, "data-bridge-ios-image"
  end

  def test_native_menu_tag
    html = native_menu_tag(title: "Actions", side: :left) do |menu|
      menu.item "Edit", "/edit"
      menu.item "Delete", "/delete", method: :delete, destructive: true
    end

    assert_includes html, 'style="display:none"'
    assert_includes html, 'data-controller="bridge--menu"'
    assert_includes html, 'data-bridge--menu-title-value="Actions"'
    assert_includes html, 'data-bridge--menu-side-value="left"'
    assert_includes html, ">Edit</a>"
    assert_includes html, 'data-bridge--menu-target="item"'
    assert_includes html, 'data-turbo-method="delete"'
    assert_includes html, 'data-destructive'
    assert_includes html, 'hidden="hidden"'
    refute_includes html, 'd-none'
  end

  def test_native_menu_tag_defaults_to_right
    html = native_menu_tag(title: "Menu") do |menu|
      menu.item "Item", "/item"
    end

    assert_includes html, 'data-bridge--menu-side-value="right"'
  end

  def test_native_badge_tag_with_count
    html = native_badge_tag(5)
    assert_includes html, 'data-native-badge'
    assert_includes html, 'data-native-badge-home="5"'
    assert_includes html, 'data-native-badge-tab="5"'
    assert_includes html, 'hidden'
    assert_includes html, 'data-controller="bridge--badge"'
    assert_includes html, 'data-bridge--badge-home-value="5"'
    assert_includes html, 'data-bridge--badge-tab-value="5"'
  end

  def test_native_badge_tag_with_independent_values
    html = native_badge_tag(home: 2, tab: 3)
    assert_includes html, 'data-native-badge-home="2"'
    assert_includes html, 'data-native-badge-tab="3"'
    assert_includes html, 'data-bridge--badge-home-value="2"'
    assert_includes html, 'data-bridge--badge-tab-value="3"'
  end

  def test_native_badge_tag_home_only
    html = native_badge_tag(home: 2)
    assert_includes html, 'data-native-badge-home="2"'
    refute_includes html, 'data-native-badge-tab'
    assert_includes html, 'data-bridge--badge-home-value="2"'
    refute_includes html, 'data-bridge--badge-tab-value'
  end

  def test_native_badge_tag_tab_only
    html = native_badge_tag(tab: 3)
    refute_includes html, 'data-native-badge-home'
    assert_includes html, 'data-native-badge-tab="3"'
    refute_includes html, 'data-bridge--badge-home-value'
    assert_includes html, 'data-bridge--badge-tab-value="3"'
  end

  def test_native_badge_tag_zero_clears_both
    html = native_badge_tag(0)
    assert_includes html, 'data-native-badge-home="0"'
    assert_includes html, 'data-native-badge-tab="0"'
    assert_includes html, 'data-bridge--badge-home-value="0"'
    assert_includes html, 'data-bridge--badge-tab-value="0"'
  end

  def test_native_navbar_tag
    html = native_navbar_tag("Today")
    assert_includes html, 'data-native-navbar="Today"'
    assert_includes html, 'hidden'
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
      navbar.button title: "Add", href: "/add"
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

  def test_native_navbar_tag_button_with_action
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "ellipsis.circle", action: "menu"
    end

    assert_includes html, 'data-native-action="menu"'
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
      navbar.button icon: "ellipsis.circle", position: :leading, action: "profile-menu" do |button|
        button.item "Edit profile", value: "edit", icon: "pencil"
        button.item "Sign out", value: "sign-out", icon: "rectangle.portrait.and.arrow.right"
      end
    end

    assert_includes html, 'data-native-navbar="Profile"'
    assert_includes html, 'data-native-button'
    assert_includes html, 'data-native-menu-item'
    assert_includes html, 'data-native-title="Edit profile"'
    assert_includes html, 'data-native-value="edit"'
    assert_includes html, 'data-native-icon="pencil"'
    assert_includes html, 'data-native-title="Sign out"'
    assert_includes html, 'data-native-value="sign-out"'
  end

  def test_native_navbar_tag_menu_item_selected
    html = native_navbar_tag("Page") do |navbar|
      navbar.button icon: "line.3.horizontal.decrease", action: "filter" do |button|
        button.item "All", value: "all", selected: true
        button.item "Active", value: "active"
      end
    end

    assert_match(/data-native-value="all".*data-native-selected/, html)
    refute_match(/data-native-value="active".*data-native-selected/, html)
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
      navbar.button icon: "trash", action: "delete"
      navbar.submit_button title: "Save"
    end

    assert_includes html, 'data-native-icon="trash"'
    assert_includes html, 'data-native-action="delete"'
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

  def test_native_navbar_tag_submit_button
    html = native_navbar_tag("Edit habit") do |navbar|
      navbar.submit_button title: "Save"
    end

    assert_includes html, 'data-native-navbar="Edit habit"'
    assert_includes html, 'data-native-submit-button'
    assert_includes html, 'data-native-title="Save"'
    assert_includes html, "data-native-selector"
  end

  def test_native_navbar_tag_submit_button_defaults
    html = native_navbar_tag("Page") do |navbar|
      navbar.submit_button
    end

    assert_includes html, 'data-native-title="Save"'
    assert_includes html, "data-native-selector"
  end

  def test_native_navbar_tag_submit_button_custom_selector
    html = native_navbar_tag("Page") do |navbar|
      navbar.submit_button title: "Create", selector: "#my-submit"
    end

    assert_includes html, 'data-native-title="Create"'
    assert_includes html, 'data-native-selector="#my-submit"'
  end

  def test_native_haptic_data_defaults_to_success
    data = native_haptic_data
    assert_equal "success", data[:native_haptic]
    assert_equal "bridge--haptic", data[:controller]
    assert_equal "success", data[:bridge__haptic_feedback_value]
  end

  def test_native_haptic_data_with_symbol_feedback
    data = native_haptic_data(:error)
    assert_equal "error", data[:native_haptic]
    assert_equal "error", data[:bridge__haptic_feedback_value]
  end

  def test_native_haptic_data_with_string_feedback
    data = native_haptic_data("warning")
    assert_equal "warning", data[:native_haptic]
    assert_equal "warning", data[:bridge__haptic_feedback_value]
  end

  def test_native_haptic_data_nil_defaults_to_success
    data = native_haptic_data(nil)
    assert_equal "success", data[:native_haptic]
    assert_equal "success", data[:bridge__haptic_feedback_value]
  end

  def test_native_haptic_data_blank_defaults_to_success
    data = native_haptic_data("")
    assert_equal "success", data[:native_haptic]
    assert_equal "success", data[:bridge__haptic_feedback_value]
  end

  def test_native_haptic_data_merges_existing_controller
    data = native_haptic_data(:success, controller: "my-controller")
    assert_equal "my-controller bridge--haptic", data[:controller]
  end

  def test_native_haptic_data_preserves_other_data_keys
    data = native_haptic_data(:success, turbo_method: :delete, id: "btn")
    assert_equal :delete, data[:turbo_method]
    assert_equal "btn", data[:id]
    assert_equal "bridge--haptic", data[:controller]
  end

  private

  def request
    @request
  end
end
