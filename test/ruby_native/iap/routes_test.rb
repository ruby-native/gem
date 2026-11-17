require "test_helper"

class RubyNative::IAP::RoutesTest < ActionDispatch::IntegrationTest
  def setup
    RubyNative.iap_enabled = false
    load RubyNative::Engine.root.join("config/routes.rb")
  end

  def teardown
    RubyNative.iap_enabled = true
    load RubyNative::Engine.root.join("config/routes.rb")
  end

  def test_iap_and_apple_webhook_routes_are_unavailable
    ["/native/iap/purchases", "/native/iap/completions/uuid", "/native/iap/restore", "/native/webhooks/apple"].each do |path|
      post path
      assert_response :not_found, path
    end
  end

  def test_other_native_routes_remain_available
    get "/native/config"
    assert_response :ok
  end
end
