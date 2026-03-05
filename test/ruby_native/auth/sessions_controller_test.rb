require "test_helper"

class RubyNative::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  def test_returns_unauthorized_when_token_is_invalid
    get "/native/auth/session", params: {token: "bogus"}

    assert_response :unauthorized
  end

  def test_returns_redirect_url_when_token_is_valid
    token = build_token(cookies: [], redirect_url: "/menu")

    get "/native/auth/session", params: {token: token}

    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal "/menu", body["redirect_url"]
  end

  def test_returns_cookies_from_token
    token = build_token(cookies: ["_session_id=abc123; path=/"], redirect_url: "/menu")

    get "/native/auth/session", params: {token: token}

    assert_response :ok
    body = JSON.parse(response.body)
    assert_includes body["cookies"], "_session_id=abc123; path=/"
  end

  def test_no_set_cookie_header_when_token_cookies_empty
    token = build_token(cookies: [], redirect_url: "/menu")

    get "/native/auth/session", params: {token: token}

    assert_response :ok
    refute response.headers["set-cookie"]&.include?("_session_id"),
      "Expected no session cookie in response"
  end

  private

  def build_token(cookies:, redirect_url:)
    RubyNative::OAuthMiddleware.build_token(cookies: cookies, redirect_url: redirect_url)
  end
end
