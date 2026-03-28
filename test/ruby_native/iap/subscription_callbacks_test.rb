require "test_helper"

class RubyNative::SubscriptionCallbacksTest < Minitest::Test
  def setup
    @original_callbacks = RubyNative.subscription_callbacks.dup
    RubyNative.subscription_callbacks.clear
  end

  def teardown
    RubyNative.subscription_callbacks.replace(@original_callbacks)
  end

  def test_on_subscription_change_registers_callback
    RubyNative.on_subscription_change { |_event| }
    assert_equal 1, RubyNative.subscription_callbacks.size
  end

  def test_fire_calls_all_registered_callbacks
    results = []
    RubyNative.on_subscription_change { |event| results << "first:#{event.type}" }
    RubyNative.on_subscription_change { |event| results << "second:#{event.type}" }

    RubyNative.fire_subscription_callbacks(build_event)

    assert_equal ["first:subscription.created", "second:subscription.created"], results
  end

  def test_fire_with_no_callbacks_does_not_raise
    RubyNative.fire_subscription_callbacks(build_event)
  end

  private

  def build_event
    RubyNative::IAP::Event.new(
      type: "subscription.created",
      status: "active",
      owner_token: "user_1",
      product_id: "com.example.annual",
      original_transaction_id: "orig_1",
      transaction_id: "txn_1",
      purchase_date: Time.current,
      expires_date: 1.year.from_now,
      environment: "sandbox",
      notification_uuid: SecureRandom.uuid,
      success_path: "/home"
    )
  end
end
