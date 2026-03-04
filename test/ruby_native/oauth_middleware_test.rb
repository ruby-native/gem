require "test_helper"

class RubyNative::OAuthMiddlewareTest < Minitest::Test
  def setup
    RubyNative.load_config
  end

  def test_non_oauth_request_passes_through
    app = build_middleware([200, {"content-type" => "text/html"}, ["OK"]])
    env = Rack::MockRequest.env_for("/some/path")

    status, headers, body = app.call(env)

    assert_equal 200, status
    assert_equal "text/html", headers["content-type"]
    assert_equal ["OK"], body
  end

  def test_oauth_path_without_ruby_native_param_passes_through
    app = build_middleware([302, {"location" => "/callback"}, [""]])
    env = Rack::MockRequest.env_for("/auth/test_provider")

    status, _headers, _body = app.call(env)

    assert_equal 302, status
  end

  def test_sets_cookie_on_oauth_start_with_redirect
    app = build_middleware([302, {"location" => "https://provider.com/oauth"}, [""]])
    env = Rack::MockRequest.env_for("/auth/test_provider?ruby_native=1&callback_scheme=rubynative-com-example-app")

    _status, headers, _body = app.call(env)

    assert headers["set-cookie"]&.include?(RubyNative::OAuthMiddleware::COOKIE_NAME),
      "Expected set-cookie header to contain #{RubyNative::OAuthMiddleware::COOKIE_NAME}"
  end

  def test_does_not_set_cookie_on_200_response
    app = build_middleware([200, {}, ["OK"]])
    env = Rack::MockRequest.env_for("/auth/test_provider?ruby_native=1&callback_scheme=rubynative-com-example-app")

    _status, headers, _body = app.call(env)

    refute headers["set-cookie"]&.include?(RubyNative::OAuthMiddleware::COOKIE_NAME),
      "Expected no tracking cookie on non-redirect response"
  end

  def test_intercepts_internal_redirect_with_valid_cookie
    scheme = "rubynative-com-example-app"
    app = build_middleware([302, {"location" => "/menu", "set-cookie" => "_session_id=abc123"}, [""]])
    env = Rack::MockRequest.env_for("/auth/callback", "HTTP_COOKIE" => "#{RubyNative::OAuthMiddleware::COOKIE_NAME}=#{sign_cookie(scheme)}")

    status, headers, _body = app.call(env)

    assert_equal 302, status
    assert_match %r{^#{scheme}://auth/callback\?token=}, headers["location"]
  end

  def test_token_contains_session_data
    scheme = "rubynative-com-example-app"
    app = build_middleware([302, {"location" => "/dashboard", "set-cookie" => "_session_id=abc123"}, [""]])
    env = Rack::MockRequest.env_for("/auth/callback", "HTTP_COOKIE" => "#{RubyNative::OAuthMiddleware::COOKIE_NAME}=#{sign_cookie(scheme)}")

    _status, headers, _body = app.call(env)

    token = extract_token(headers["location"])
    data = RubyNative::OAuthMiddleware.read_token(token)

    refute_nil data
    assert_kind_of Array, data[:cookies]
    assert_includes data[:cookies], "_session_id=abc123"
    assert_equal "/dashboard", data[:redirect_url]
  end

  def test_native_redirect_does_not_include_tracking_cookie
    scheme = "rubynative-com-example-app"
    app = build_middleware([302, {"location" => "/menu"}, [""]])
    env = Rack::MockRequest.env_for("/auth/callback", "HTTP_COOKIE" => "#{RubyNative::OAuthMiddleware::COOKIE_NAME}=#{sign_cookie(scheme)}")

    _status, headers, _body = app.call(env)

    refute headers["set-cookie"]&.include?(RubyNative::OAuthMiddleware::COOKIE_NAME),
      "Native redirect should not contain the tracking cookie"
  end

  def test_auth_failure_redirects_with_error
    scheme = "rubynative-com-example-app"
    app = build_middleware([302, {"location" => "/auth/failure?message=access_denied"}, [""]])
    env = Rack::MockRequest.env_for("/auth/callback", "HTTP_COOKIE" => "#{RubyNative::OAuthMiddleware::COOKIE_NAME}=#{sign_cookie(scheme)}")

    status, headers, _body = app.call(env)

    assert_equal 302, status
    assert_equal "#{scheme}://auth/callback?error=true", headers["location"]
  end

  def test_external_redirect_passes_through
    scheme = "rubynative-com-example-app"
    app = build_middleware([302, {"location" => "https://other-host.com/page"}, [""]])
    env = Rack::MockRequest.env_for("http://localhost/auth/callback", "HTTP_COOKIE" => "#{RubyNative::OAuthMiddleware::COOKIE_NAME}=#{sign_cookie(scheme)}")

    status, headers, _body = app.call(env)

    assert_equal 302, status
    assert_equal "https://other-host.com/page", headers["location"]
  end

  def test_oauth_start_relaxes_session_cookie_samesite
    session_cookie = "_myapp_session=abc123; path=/; SameSite=Lax"
    app = build_middleware([302, {"location" => "https://provider.com/oauth", "set-cookie" => session_cookie}, [""]])
    env = Rack::MockRequest.env_for("/auth/test_provider?ruby_native=1&callback_scheme=rubynative-com-example-app")

    _status, headers, _body = app.call(env)

    all_cookies = Array(headers["set-cookie"]).join("\n")
    assert_match(/samesite=none/i, all_cookies)
    refute_match(/samesite=lax/i, all_cookies)
    assert_match(/secure/i, all_cookies)
  end

  def test_oauth_start_relaxes_samesite_without_ruby_native_param
    session_cookie = "_myapp_session=abc123; path=/; SameSite=Lax"
    app = build_middleware([302, {"location" => "https://provider.com/oauth", "set-cookie" => session_cookie}, [""]])
    env = Rack::MockRequest.env_for("/auth/test_provider")

    _status, headers, _body = app.call(env)

    all_cookies = Array(headers["set-cookie"]).join("\n")
    assert_match(/samesite=none/i, all_cookies)
    refute_match(/samesite=lax/i, all_cookies)
  end

  def test_tracking_cookie_uses_samesite_none
    app = build_middleware([302, {"location" => "https://provider.com/oauth"}, [""]])
    env = Rack::MockRequest.env_for("/auth/test_provider?ruby_native=1&callback_scheme=rubynative-com-example-app")

    _status, headers, _body = app.call(env)

    cookie = Array(headers["set-cookie"]).join("\n")
    assert_match(/samesite=none/i, cookie)
    assert_match(/secure/i, cookie)
  end

  def test_invalid_cookie_does_not_intercept
    app = build_middleware([302, {"location" => "/menu"}, [""]])
    env = Rack::MockRequest.env_for("/auth/callback", "HTTP_COOKIE" => "#{RubyNative::OAuthMiddleware::COOKIE_NAME}=tampered-value")

    status, headers, _body = app.call(env)

    assert_equal 302, status
    assert_equal "/menu", headers["location"]
  end

  private

  def build_middleware(response)
    RubyNative::OAuthMiddleware.new(FakeApp.new(response))
  end

  def sign_cookie(scheme)
    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      digest: "SHA256",
      purpose: "ruby_native_oauth"
    )
    verifier.generate(scheme)
  end

  def extract_token(location)
    encoded = location.match(/token=(.+)/)[1]
    CGI.unescape(encoded)
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
