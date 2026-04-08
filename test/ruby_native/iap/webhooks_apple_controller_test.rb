require "test_helper"

class RubyNative::Webhooks::AppleControllerTest < ActionDispatch::IntegrationTest
  def test_returns_bad_request_for_invalid_json
    post "/native/webhooks/apple",
      params: "not json",
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :bad_request
  end

  def test_returns_unprocessable_entity_for_invalid_jws
    post "/native/webhooks/apple",
      params: {signedPayload: "invalid.jws.payload"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :unprocessable_entity
  end

  def test_returns_ok_for_test_notification
    header = Base64.urlsafe_encode64({alg: "ES256"}.to_json, padding: false)
    payload = Base64.urlsafe_encode64({notificationType: "TEST", notificationUUID: "test-123"}.to_json, padding: false)
    jws = "#{header}.#{payload}.fakesignature"

    post "/native/webhooks/apple",
      params: {signedPayload: jws}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :ok
  end

  def test_returns_ok_for_missing_signed_payload
    # Missing signedPayload is silently ignored (nothing to process).
    post "/native/webhooks/apple",
      params: {unexpected: "format"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :ok
  end
end
