require "test_helper"

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

  def test_returns_not_found_for_unknown_uuid
    post "/native/iap/completions/nonexistent"

    assert_response :not_found
  end
end
