require "test_helper"

class RubyNative::IAP::RestoresControllerTest < ActionDispatch::IntegrationTest
  def setup
    @original_callbacks = RubyNative.subscription_callbacks.dup
    RubyNative.subscription_callbacks.clear
  end

  def teardown
    RubyNative.subscription_callbacks.replace(@original_callbacks) if @original_callbacks
  end

  def test_returns_bad_request_without_customer_id
    post "/native/iap/restore",
      params: {signed_transactions: ["fake"]}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :bad_request
  end

  def test_returns_bad_request_without_signed_transactions
    post "/native/iap/restore",
      params: {customer_id: "user_42"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :bad_request
  end

  def test_returns_unprocessable_entity_for_invalid_jws
    post "/native/iap/restore",
      params: {customer_id: "user_42", signed_transactions: ["invalid.jws.payload"]}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    assert_response :unprocessable_entity
  end
end
