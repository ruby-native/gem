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
    controller = FakeController.new(FakeRequest.new("Ruby Native/1.0"))
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
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0 Ruby Native/2.0 CFNetwork"))
    assert controller.native_app?
  end
end
