require "test_helper"

class RubyNative::Webhooks::AppleControllerTest < ActionDispatch::IntegrationTest
  def test_returns_bad_request_for_invalid_json
    post "/native/webhooks/apple",
      params: "not json",
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :bad_request
  end

  def test_returns_ok_for_invalid_jws
    # Returns 200 so Apple doesn't retry unprocessable payloads
    post "/native/webhooks/apple",
      params: {signedPayload: "invalid.jws.payload"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :ok
  end

  def test_returns_ok_for_missing_signed_payload
    # Returns 200 so Apple doesn't retry
    post "/native/webhooks/apple",
      params: {unexpected: "format"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :ok
  end
end
