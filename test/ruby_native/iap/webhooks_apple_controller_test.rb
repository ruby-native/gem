require "test_helper"
require "support/storekit_signing"

class RubyNative::Webhooks::AppleControllerTest < ActionDispatch::IntegrationTest
  def setup
    RubyNative::IAP::PurchaseIntent.delete_all
    @original_callbacks = RubyNative.subscription_callbacks.dup
    RubyNative.subscription_callbacks.clear
    @events = []
    RubyNative.on_subscription_change { |event| @events << event }
    @chain = StoreKitSigning.new
  end

  def teardown
    RubyNative.subscription_callbacks.replace(@original_callbacks)
  end

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

  # --- Signed notifications ---

  def test_a_signed_notification_fires_the_callback
    intent = RubyNative::IAP::PurchaseIntent.create!(customer_id: "user_42", product_id: "com.example.annual")

    StoreKitSigning.with_bundle_id("com.example.app") do
      @chain.trusted { notify(signed_notification(app_account_token: intent.uuid)) }
    end

    assert_response :ok
    event = @events.sole
    assert_equal "subscription.updated", event.type
    assert_equal "user_42", event.owner_token
    assert_equal "com.example.annual", event.product_id
    assert_equal "sandbox", event.environment
    assert intent.reload.completed?
  end

  def test_rejects_a_notification_for_another_bundle_id
    StoreKitSigning.with_bundle_id("com.example.app") do
      @chain.trusted { notify(signed_notification(bundle_id: "com.example.other")) }
    end

    assert_response :unprocessable_entity
    assert_empty @events
  end

  def test_rejects_a_notification_whose_transaction_is_for_another_bundle_id
    StoreKitSigning.with_bundle_id("com.example.app") do
      @chain.trusted { notify(signed_notification(transaction_bundle_id: "com.example.other")) }
    end

    assert_response :unprocessable_entity
    assert_empty @events
  end

  def test_rejects_a_notification_from_an_untrusted_chain
    notify(signed_notification)

    assert_response :unprocessable_entity
    assert_empty @events
  end

  def test_rejects_a_notification_whose_chain_has_an_entry_that_is_not_a_certificate
    x5c = [Base64.strict_encode64("not a certificate"), *@chain.x5c.drop(1)]

    @chain.trusted { notify(signed_notification(x5c: x5c)) }

    assert_response :unprocessable_entity
    assert_empty @events
  end

  private

  def notify(signed_payload)
    post "/native/webhooks/apple",
      params: {signedPayload: signed_payload}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}
  end

  def signed_notification(
    app_account_token: "no-such-intent", bundle_id: "com.example.app", transaction_bundle_id: "com.example.app", x5c: @chain.x5c
  )
    transaction = {
      "appAccountToken" => app_account_token,
      "bundleId" => transaction_bundle_id,
      "productId" => "com.example.annual",
      "originalTransactionId" => "2000000000000000",
      "transactionId" => "2000000000000001",
      "purchaseDate" => Time.utc(2026, 1, 1).to_i * 1000,
      "expiresDate" => Time.utc(2027, 1, 1).to_i * 1000
    }

    @chain.sign(
      {
        "notificationType" => "DID_RENEW",
        "notificationUUID" => "notification-uuid",
        "data" => {
          "bundleId" => bundle_id,
          "environment" => "Sandbox",
          "signedTransactionInfo" => @chain.sign(transaction)
        }
      },
      x5c: x5c
    )
  end
end
