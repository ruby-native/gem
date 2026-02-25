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
    assert_equal({ controller: "bridge--form" }, data)
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

  FakeRequest = Struct.new(:user_agent)

  def test_native_app_with_ruby_native_user_agent
    @request = FakeRequest.new("Ruby Native/1.0")
    assert native_app?
  end

  def test_native_app_without_ruby_native_user_agent
    @request = FakeRequest.new("Mozilla/5.0")
    refute native_app?
  end

  def test_native_app_with_nil_user_agent
    @request = FakeRequest.new(nil)
    refute native_app?
  end

  def test_native_back_button_tag
    html = native_back_button_tag
    assert_includes html, "<button"
    assert_includes html, ">Back</button>"
    assert_includes html, 'class="native-back-button"'
    assert_includes html, "webkit.messageHandlers.rubyNative.postMessage({action: &#39;back&#39;})"
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

  private

  def request
    @request
  end
end
