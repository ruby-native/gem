require "test_helper"

class RubyNative::IAP::EventTest < Minitest::Test
  def test_active_when_status_is_active
    event = build_event(status: "active")
    assert event.active?
    refute event.expired?
  end

  def test_expired_when_status_is_expired
    event = build_event(status: "expired")
    assert event.expired?
    refute event.active?
  end

  def test_created_when_type_is_subscription_created
    event = build_event(type: "subscription.created")
    assert event.created?
    refute event.canceled?
  end

  def test_canceled_when_type_is_subscription_canceled
    event = build_event(type: "subscription.canceled")
    assert event.canceled?
    refute event.created?
  end

  def test_exposes_all_attributes
    event = build_event(
      owner_token: "user_42",
      product_id: "com.example.annual",
      original_transaction_id: "orig_123",
      transaction_id: "txn_456",
      environment: "sandbox",
      success_path: "/dashboard"
    )

    assert_equal "user_42", event.owner_token
    assert_equal "com.example.annual", event.product_id
    assert_equal "orig_123", event.original_transaction_id
    assert_equal "txn_456", event.transaction_id
    assert_equal "sandbox", event.environment
    assert_equal "/dashboard", event.success_path
  end

  private

  def build_event(**overrides)
    RubyNative::IAP::Event.new(**{
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
    }.merge(overrides))
  end
end
