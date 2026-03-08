require "test_helper"

class RubyNative::InertiaSupportTest < Minitest::Test
  FakeRequest = Struct.new(:user_agent)

  class FakeController
    def self.inertia_share(&block)
      @inertia_share_block = block
    end

    def self.inertia_share_block
      @inertia_share_block
    end

    include RubyNative::NativeDetection
    include RubyNative::InertiaSupport

    attr_accessor :request

    def initialize(request)
      @request = request
    end

    def shared_data
      instance_eval(&self.class.inertia_share_block)
    end
  end

  def test_shares_native_app_true_for_native_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native/1.0"))
    assert_equal true, controller.shared_data[:native_app]
  end

  def test_shares_native_app_false_for_browser_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    assert_equal false, controller.shared_data[:native_app]
  end

  def test_shares_native_form_false_by_default
    controller = FakeController.new(FakeRequest.new("Ruby Native/1.0"))
    assert_equal false, controller.shared_data[:native_form]
  end

  def test_shares_native_form_true_when_set
    controller = FakeController.new(FakeRequest.new("Ruby Native/1.0"))
    controller.instance_variable_set(:@native_form, true)
    assert_equal true, controller.shared_data[:native_form]
  end

  def test_only_shares_native_app_and_native_form
    controller = FakeController.new(FakeRequest.new("Ruby Native/1.0"))
    assert_equal [:native_app, :native_form], controller.shared_data.keys
  end
end
