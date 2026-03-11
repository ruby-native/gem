require "test_helper"

class RubyNative::TunnelCookieMiddlewareTest < Minitest::Test
  def test_passes_through_non_tunnel_request
    app = build_middleware([200, {"set-cookie" => "_session=abc; domain=.example.com; path=/"}, ["OK"]])
    env = Rack::MockRequest.env_for("http://example.com/")

    status, headers, body = app.call(env)

    assert_equal 200, status
    assert_match(/domain=\.example\.com/i, headers["set-cookie"])
    assert_equal ["OK"], body
  end

  def test_strips_domain_from_tunnel_request
    cookie = "_session=abc; domain=.trycloudflare.com; path=/; HttpOnly"
    app = build_middleware([200, {"set-cookie" => cookie}, ["OK"]])
    env = Rack::MockRequest.env_for("http://abc-123.trycloudflare.com/")

    _status, headers, _body = app.call(env)

    refute_match(/domain=/i, headers["set-cookie"])
    assert_match(/_session=abc/, headers["set-cookie"])
    assert_match(/path=\//, headers["set-cookie"])
    assert_match(/HttpOnly/, headers["set-cookie"])
  end

  def test_strips_domain_from_multiple_cookies
    cookies = [
      "_session=abc; domain=.trycloudflare.com; path=/",
      "_csrf=xyz; domain=.trycloudflare.com; path=/"
    ].join("\n")
    app = build_middleware([200, {"set-cookie" => cookies}, ["OK"]])
    env = Rack::MockRequest.env_for("http://abc-123.trycloudflare.com/")

    _status, headers, _body = app.call(env)

    refute_match(/domain=/i, headers["set-cookie"])
    assert_match(/_session=abc/, headers["set-cookie"])
    assert_match(/_csrf=xyz/, headers["set-cookie"])
  end

  def test_preserves_cookies_without_domain
    cookie = "_session=abc; path=/; HttpOnly"
    app = build_middleware([200, {"set-cookie" => cookie}, ["OK"]])
    env = Rack::MockRequest.env_for("http://abc-123.trycloudflare.com/")

    _status, headers, _body = app.call(env)

    assert_equal cookie, headers["set-cookie"]
  end

  def test_no_op_when_no_set_cookie_header
    app = build_middleware([200, {"content-type" => "text/html"}, ["OK"]])
    env = Rack::MockRequest.env_for("http://abc-123.trycloudflare.com/")

    status, headers, body = app.call(env)

    assert_equal 200, status
    assert_nil headers["set-cookie"]
    assert_equal ["OK"], body
  end

  def test_does_not_strip_domain_for_localhost
    cookie = "_session=abc; domain=.localhost; path=/"
    app = build_middleware([200, {"set-cookie" => cookie}, ["OK"]])
    env = Rack::MockRequest.env_for("http://localhost:3000/")

    _status, headers, _body = app.call(env)

    assert_match(/domain=\.localhost/i, headers["set-cookie"])
  end

  private

  def build_middleware(response)
    RubyNative::TunnelCookieMiddleware.new(FakeApp.new(response))
  end

  class FakeApp
    def initialize(response)
      @response = response
    end

    def call(_env)
      @response
    end
  end
end
