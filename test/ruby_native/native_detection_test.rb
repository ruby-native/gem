require "test_helper"

class RubyNative::NativeDetectionTest < Minitest::Test
  FakeRequest = Struct.new(:user_agent)

  class FakeController
    include RubyNative::NativeDetection

    attr_accessor :request

    def initialize(request)
      @request = request
    end
  end

  def test_native_app_returns_true_for_ruby_native_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4"))
    assert controller.native_app?
  end

  def test_native_app_returns_false_for_browser_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    refute controller.native_app?
  end

  def test_native_app_returns_false_for_nil_user_agent
    controller = FakeController.new(FakeRequest.new(nil))
    refute controller.native_app?
  end

  def test_native_app_returns_true_when_user_agent_contains_ruby_native
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0 Ruby Native iOS/1.4 CFNetwork"))
    assert controller.native_app?
  end

  def test_native_version_returns_version_from_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4"))
    assert_equal RubyNative::NativeVersion.new("1.4"), controller.native_version
  end

  def test_native_version_returns_version_embedded_in_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0 Ruby Native iOS/2.0 CFNetwork"))
    assert_equal RubyNative::NativeVersion.new("2.0"), controller.native_version
  end

  def test_native_version_returns_zero_for_browser_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    assert_equal RubyNative::NativeVersion.new("0"), controller.native_version
  end

  def test_native_version_returns_zero_for_nil_user_agent
    controller = FakeController.new(FakeRequest.new(nil))
    assert_equal RubyNative::NativeVersion.new("0"), controller.native_version
  end

  def test_native_version_handles_three_part_version
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.3.2"))
    assert_equal RubyNative::NativeVersion.new("1.3.2"), controller.native_version
  end

  def test_native_version_supports_string_comparison
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4"))
    assert controller.native_version >= "1.3"
    refute controller.native_version >= "2.0"
  end
end
