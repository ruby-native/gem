require "test_helper"

class RubyNative::IAP::RoutesTest < ActionDispatch::IntegrationTest
  def setup
    RubyNative.iap_enabled = false
    reload_engine_routes
  end

  def teardown
    RubyNative.iap_enabled = true
    reload_engine_routes
  end

  def test_iap_is_off_by_default
    assert_equal false, ROUTE_DEFAULTS[:iap_enabled]
  end

  def test_iap_and_apple_webhook_routes_are_unavailable
    ["/native/iap/purchases", "/native/iap/completions/uuid", "/native/iap/restore", "/native/webhooks/apple"].each do |path|
      post path
      assert_response :not_found, path
    end
  end

  # A Google Play webhook added later has to land inside the same flag.
  def test_no_iap_or_webhook_route_is_drawn
    paths = RubyNative::Engine.routes.routes.map { |route| route.path.spec.to_s }

    assert_empty paths.grep(%r{\A/(iap|webhooks)/})
  end

  def test_other_native_routes_remain_available
    get "/native/config"
    assert_response :ok
  end

  private

  def reload_engine_routes
    load RubyNative::Engine.root.join("config/routes.rb")
  end
end
