require "test_helper"

class RubyNative::Auth::StartControllerTest < ActionDispatch::IntegrationTest
  def test_returns_200
    get "/native/auth/start/google", params: {callback_scheme: "rubynative-com-example-app"}

    assert_response :ok
  end

  def test_response_contains_form_posting_to_provider
    get "/native/auth/start/google", params: {callback_scheme: "rubynative-com-example-app"}

    assert_includes response.body, 'action="/auth/google"'
    assert_includes response.body, 'method="post"'
  end

  def test_response_contains_ruby_native_hidden_input
    get "/native/auth/start/google", params: {callback_scheme: "rubynative-com-example-app"}

    assert_includes response.body, 'name="ruby_native"'
    assert_includes response.body, 'value="1"'
  end

  def test_response_contains_callback_scheme_hidden_input
    get "/native/auth/start/github", params: {callback_scheme: "rubynative-dev-myapp"}

    assert_includes response.body, 'name="callback_scheme"'
    assert_includes response.body, 'value="rubynative-dev-myapp"'
  end

  def test_rejects_invalid_provider_name
    get "/native/auth/start/INVALID-Provider!", params: {callback_scheme: "rubynative-com-example-app"}

    assert_response :bad_request
  end
end
