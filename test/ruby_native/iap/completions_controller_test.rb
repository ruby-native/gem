require "test_helper"
require "support/storekit_signing"

class RubyNative::IAP::CompletionsControllerTest < ActionDispatch::IntegrationTest
  def setup
    RubyNative::IAP::PurchaseIntent.delete_all
    @original_callbacks = RubyNative.subscription_callbacks.dup
    RubyNative.subscription_callbacks.clear
  end

  def teardown
    RubyNative.subscription_callbacks.replace(@original_callbacks) if @original_callbacks
  end

  def test_completes_intent_and_fires_callback
    intent = RubyNative::IAP::PurchaseIntent.create!(
      customer_id: "user_42",
      product_id: "com.example.annual",
      success_path: "/dashboard"
    )

    received_event = nil
    RubyNative.on_subscription_change { |event| received_event = event }

    post "/native/iap/completions/#{intent.uuid}"

    assert_response :ok

    intent.reload
    assert intent.completed?
    assert intent.xcode?

    assert received_event.present?
    assert_equal "subscription.created", received_event.type
    assert_equal "user_42", received_event.owner_token
    assert_equal "com.example.annual", received_event.product_id
    assert_equal "/dashboard", received_event.success_path
    assert received_event.active?
  end

  def test_returns_ok_for_already_completed_intent
    intent = RubyNative::IAP::PurchaseIntent.create!(
      customer_id: "user_42",
      product_id: "com.example.annual",
      status: :completed,
      environment: :xcode
    )

    callback_fired = false
    RubyNative.on_subscription_change { |_| callback_fired = true }

    post "/native/iap/completions/#{intent.uuid}"

    assert_response :ok
    assert_not callback_fired
  end

  def test_returns_not_found_for_unknown_uuid
    post "/native/iap/completions/nonexistent"

    assert_response :not_found
  end

  # --- Signed transactions ---

  def test_a_signed_transaction_completes_the_intent_with_what_apple_signed
    chain = StoreKitSigning.new
    intent = create_intent
    events = capture_events

    chain.trusted { in_production { complete(intent, chain.sign(transaction_for(intent))) } }

    assert_response :ok
    assert intent.reload.completed?
    assert intent.production?
    event = events.sole
    assert_equal "subscription.created", event.type
    assert_equal "user_42", event.owner_token
    assert_equal "com.example.lifetime", event.product_id
    assert_equal "2000000000000000", event.original_transaction_id
    assert_equal "2000000000000001", event.transaction_id
    assert_equal Time.utc(2026, 1, 1), event.purchase_date
    assert_equal Time.utc(2027, 1, 1), event.expires_date
    assert_equal "production", event.environment
    assert_equal "/dashboard", event.success_path
  end

  def test_production_rejects_a_completion_with_no_signed_transaction
    intent = create_intent
    events = capture_events

    in_production { post "/native/iap/completions/#{intent.uuid}" }

    assert_rejected intent, events
  end

  def test_production_rejects_a_blank_signed_transaction
    intent = create_intent
    events = capture_events

    in_production { complete(intent, "") }

    assert_rejected intent, events
  end

  def test_rejects_a_transaction_signed_by_an_untrusted_chain
    chain = StoreKitSigning.new
    intent = create_intent
    events = capture_events

    in_production { complete(intent, chain.sign(transaction_for(intent))) }

    assert_rejected intent, events
  end

  def test_rejects_a_transaction_altered_after_signing
    chain = StoreKitSigning.new
    intent = create_intent
    events = capture_events
    header, _payload, signature = chain.sign(transaction_for(intent)).split(".")
    altered = Base64.urlsafe_encode64(transaction_for(intent).merge("productId" => "com.example.other").to_json, padding: false)

    chain.trusted { in_production { complete(intent, [header, altered, signature].join(".")) } }

    assert_rejected intent, events
  end

  def test_rejects_a_transaction_signed_for_another_intent
    chain = StoreKitSigning.new
    intent = create_intent
    other = create_intent
    events = capture_events

    chain.trusted { in_production { complete(intent, chain.sign(transaction_for(other))) } }

    assert_rejected intent, events
  end

  def test_rejects_a_string_that_is_not_a_jws
    intent = create_intent
    events = capture_events

    in_production { complete(intent, "not.a.jws") }

    assert_rejected intent, events
  end

  def test_rejects_a_chain_with_an_entry_that_is_not_a_certificate
    chain = StoreKitSigning.new
    intent = create_intent
    events = capture_events
    x5c = [Base64.strict_encode64("not a certificate"), *chain.x5c.drop(1)]

    chain.trusted { in_production { complete(intent, chain.sign(transaction_for(intent), x5c: x5c)) } }

    assert_rejected intent, events
  end

  def test_rejects_a_leaf_that_was_expired_when_the_transaction_was_signed
    chain = StoreKitSigning.new(leaf: {not_before: Time.now - 800.days, not_after: Time.now - 70.days})
    intent = create_intent
    events = capture_events
    transaction = transaction_for(intent).merge("signedDate" => 10.days.ago.to_i * 1000)

    chain.trusted { in_production { complete(intent, chain.sign(transaction)) } }

    assert_rejected intent, events
  end

  # The unsigned fallback is for a request with no transaction at all. One that
  # fails verification must not fall through to it.
  def test_a_local_environment_still_verifies_a_signed_transaction
    chain = StoreKitSigning.new
    intent = create_intent
    events = capture_events

    complete(intent, chain.sign(transaction_for(intent)))

    assert Rails.env.local?
    assert_rejected intent, events
  end

  private

  def create_intent
    RubyNative::IAP::PurchaseIntent.create!(
      customer_id: "user_42",
      product_id: "com.example.annual",
      success_path: "/dashboard"
    )
  end

  def capture_events
    [].tap { |events| RubyNative.on_subscription_change { |event| events << event } }
  end

  def complete(intent, signed_transaction)
    post "/native/iap/completions/#{intent.uuid}",
      params: {signed_transaction: signed_transaction}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}
  end

  def transaction_for(intent)
    {
      "appAccountToken" => intent.uuid,
      "bundleId" => "com.example.app",
      "productId" => "com.example.lifetime",
      "originalTransactionId" => "2000000000000000",
      "transactionId" => "2000000000000001",
      "purchaseDate" => Time.utc(2026, 1, 1).to_i * 1000,
      "expiresDate" => Time.utc(2027, 1, 1).to_i * 1000,
      "environment" => "Production"
    }
  end

  def in_production
    original = Rails.env
    Rails.env = "production"
    yield
  ensure
    Rails.env = original
  end

  def assert_rejected(intent, events)
    assert_response :unprocessable_entity
    assert intent.reload.pending?
    assert_empty events
  end
end
