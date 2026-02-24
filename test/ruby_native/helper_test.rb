require "test_helper"

class RubyNative::HelperTest < ActionView::TestCase
  include RubyNative::Helper

  def test_native_tabs_tag
    html = native_tabs_tag
    assert_includes html, 'data-native-tabs'
    assert_includes html, 'hidden'
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

  private

  def request
    @request
  end
end
