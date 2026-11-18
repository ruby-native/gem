require "test_helper"

class RubyNative::Push::RoutesTest < ActionDispatch::IntegrationTest
  def setup
    RubyNative.push_enabled = false
    reload_engine_routes
  end

  def teardown
    RubyNative.push_enabled = true
    reload_engine_routes
  end

  def test_push_is_on_by_default
    assert_equal true, ROUTE_DEFAULTS[:push_enabled]
  end

  def test_the_push_device_route_is_unavailable
    post "/native/push/devices", params: {token: "apns-token", platform: "apple"}

    assert_response :not_found
  end

  # X-Cascade lets a host's own route at the same path answer instead.
  def test_the_engine_passes_the_request_back_to_the_host
    response = Rack::MockRequest.new(RubyNative::Engine).post("/push/devices")

    assert_equal 404, response.status
    assert_equal "pass", response.headers["X-Cascade"]
  end

  private

  def reload_engine_routes
    load RubyNative::Engine.root.join("config/routes.rb")
  end
end
