require "test_helper"
require "support/storekit_signing"

# Unlike completions, restore has no unsigned path to test through -- there is no
# Xcode fallback, because a restore has nothing to fall back to. So the signature
# check is bypassed for canned payloads only, and anything unregistered still
# goes through the real Apple certificate chain.
class RubyNative::IAP::RestoresController
  STUBBED_TRANSACTIONS = {}

  private

  def decode_and_verify_jws(jws)
    STUBBED_TRANSACTIONS.fetch(jws) { super }
  end
end

class RubyNative::IAP::RestoresControllerTest < ActionDispatch::IntegrationTest
  STUBS = RubyNative::IAP::RestoresController::STUBBED_TRANSACTIONS

  def setup
    RubyNative::IAP::PurchaseIntent.delete_all
    STUBS.clear
    @original_callbacks = RubyNative.subscription_callbacks.dup
    RubyNative.subscription_callbacks.clear
  end

  def teardown
    STUBS.clear
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

  def test_restores_to_the_account_that_made_the_purchase
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent)

    event = capture_event { restore(customer_id: "user_42") }

    assert_response :ok
    assert_equal "user_42", event.owner_token
    assert_equal "com.example.annual", event.product_id
    assert_equal "t_1", event.transaction_id
    assert event.active?
  end

  def test_ignores_the_requested_customer_id_and_uses_the_intent
    intent = create_intent(customer_id: "buyer")
    stub_transaction("jws", intent: intent)

    event = capture_event { restore(customer_id: "victim") }

    assert_response :ok
    assert_equal "buyer", event.owner_token,
      "A replayed transaction must not grant entitlement to a caller-named account"
  end

  def test_does_not_grant_entitlement_for_a_transaction_with_no_intent
    stub_transaction("jws", app_account_token: SecureRandom.uuid)

    event = capture_event { restore(customer_id: "victim") }

    assert_response :ok
    assert_nil event, "An unattributable transaction must not fire a subscription callback"
  end

  def test_does_not_grant_entitlement_when_the_app_account_token_is_missing
    create_intent(customer_id: "buyer")
    stub_transaction("jws", app_account_token: nil)

    event = capture_event { restore(customer_id: "buyer") }

    assert_response :ok
    assert_nil event
  end

  def test_replaying_the_same_transaction_fires_the_callback_once
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent)

    events = []
    RubyNative.on_subscription_change { |event| events << event }

    3.times { restore(customer_id: "user_42") }

    assert_response :ok
    assert_equal 1, events.size, "Expected the replayed transaction to be deduped on its id"
  end

  def test_a_renewal_fires_again
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent, transaction_id: "t_1")
    stub_transaction("renewal", intent: intent, transaction_id: "t_2")

    events = []
    RubyNative.on_subscription_change { |event| events << event }

    restore(customer_id: "user_42", signed_transactions: ["jws"])
    restore(customer_id: "user_42", signed_transactions: ["renewal"])

    assert_equal %w[t_1 t_2], events.map(&:transaction_id)
  end

  def test_settles_the_intent_so_a_lost_completion_recovers
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent, environment: "Sandbox")

    restore(customer_id: "user_42")

    intent.reload
    assert intent.completed?
    assert intent.sandbox?
    assert_equal "t_1", intent.restored_transaction_id
  end

  # An app can be on this version of the gem before its migration has been run.
  # The restore has to keep working: the app never reads the response, so a 500
  # here reaches the customer as "Restored!" over an entitlement that was never
  # granted.
  def test_restores_without_the_dedup_column
    without_dedup_column do
      intent = create_intent(customer_id: "user_42")
      stub_transaction("jws", intent: intent)

      event = capture_event { restore(customer_id: "user_42") }

      assert_response :ok
      assert_equal "user_42", event&.owner_token
      assert intent.reload.completed?
    end
  end

  def test_without_the_dedup_column_a_repeat_restore_fires_again
    without_dedup_column do
      intent = create_intent(customer_id: "user_42")
      stub_transaction("jws", intent: intent)

      events = []
      RubyNative.on_subscription_change { |event| events << event }

      2.times { restore(customer_id: "user_42") }

      assert_response :ok
      assert_equal 2, events.size,
        "Without the column there is nowhere to record the transaction, so this " \
        "matches how restore behaved before it existed"
    end
  end

  def test_tolerates_an_unrecognized_environment
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent, environment: "Martian")

    event = capture_event { restore(customer_id: "user_42") }

    assert_response :ok
    assert_equal "martian", event.environment
    assert intent.reload.completed?
  end

  # --- Verification ---

  def test_returns_unprocessable_entity_for_a_chain_entry_that_is_not_a_certificate
    chain = StoreKitSigning.new
    intent = create_intent(customer_id: "user_42")
    x5c = [Base64.strict_encode64("not a certificate"), *chain.x5c.drop(1)]
    jws = chain.sign({"appAccountToken" => intent.uuid, "transactionId" => "t_1"}, x5c: x5c)

    event = capture_event { chain.trusted { restore(customer_id: "user_42", signed_transactions: [jws]) } }

    assert_response :unprocessable_entity
    assert_nil event
    assert intent.reload.pending?
  end

  def test_restores_a_signed_transaction_for_the_configured_bundle_id
    chain = StoreKitSigning.new
    intent = create_intent(customer_id: "user_42")
    jws = chain.sign({"appAccountToken" => intent.uuid, "transactionId" => "t_1", "bundleId" => "com.example.app"})

    event = capture_event do
      StoreKitSigning.with_bundle_id("com.example.app") do
        chain.trusted { restore(customer_id: "user_42", signed_transactions: [jws]) }
      end
    end

    assert_response :ok
    assert_equal "user_42", event.owner_token
    assert intent.reload.completed?
  end

  def test_does_not_restore_a_transaction_for_another_bundle_id
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent, bundle_id: "com.example.other")

    event = capture_event do
      StoreKitSigning.with_bundle_id("com.example.app") { restore(customer_id: "user_42") }
    end

    assert_response :unprocessable_entity
    assert_nil event
    assert intent.reload.pending?
  end

  def test_does_not_restore_a_transaction_with_no_bundle_id_when_one_is_configured
    intent = create_intent(customer_id: "user_42")
    stub_transaction("jws", intent: intent, bundle_id: nil)

    event = capture_event do
      StoreKitSigning.with_bundle_id("com.example.app") { restore(customer_id: "user_42") }
    end

    assert_response :unprocessable_entity
    assert_nil event
    assert intent.reload.pending?
  end

  private

  # Stands in for an app that has this gem version but has not run the migration.
  def without_dedup_column
    connection = ActiveRecord::Base.connection
    connection.remove_column :ruby_native_purchase_intents, :restored_transaction_id
    RubyNative::IAP::PurchaseIntent.reset_column_information
    yield
  ensure
    connection.add_column :ruby_native_purchase_intents, :restored_transaction_id, :string
    RubyNative::IAP::PurchaseIntent.reset_column_information
  end

  def create_intent(customer_id:)
    RubyNative::IAP::PurchaseIntent.create!(
      customer_id: customer_id,
      product_id: "com.example.annual"
    )
  end

  def stub_transaction(
    jws,
    intent: nil, app_account_token: :from_intent, transaction_id: "t_1", environment: "Production", bundle_id: "com.example.app"
  )
    token = (app_account_token == :from_intent) ? intent&.uuid : app_account_token

    STUBS[jws] = {
      "appAccountToken" => token,
      "bundleId" => bundle_id,
      "productId" => "com.example.annual",
      "originalTransactionId" => "o_1",
      "transactionId" => transaction_id,
      "purchaseDate" => (Time.current.to_f * 1000).to_i,
      "expiresDate" => (1.year.from_now.to_f * 1000).to_i,
      "environment" => environment
    }
  end

  def restore(customer_id:, signed_transactions: ["jws"])
    post "/native/iap/restore",
      params: {customer_id: customer_id, signed_transactions: signed_transactions, success_path: "/thanks"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}
  end

  def capture_event
    received = nil
    RubyNative.on_subscription_change { |event| received = event }
    yield
    received
  end
end
