require "test_helper"

class RubyNative::IAP::NormalizableTest < Minitest::Test
  include RubyNative::IAP::Normalizable

  def test_subscribed_maps_to_created
    assert_equal "subscription.created", normalized_type(notification("SUBSCRIBED"))
  end

  def test_did_renew_maps_to_updated
    assert_equal "subscription.updated", normalized_type(notification("DID_RENEW"))
  end

  def test_auto_renew_disabled_maps_to_canceled
    assert_equal "subscription.canceled", normalized_type(notification("DID_CHANGE_RENEWAL_STATUS", "AUTO_RENEW_DISABLED"))
  end

  def test_auto_renew_enabled_maps_to_updated
    assert_equal "subscription.updated", normalized_type(notification("DID_CHANGE_RENEWAL_STATUS", "AUTO_RENEW_ENABLED"))
  end

  def test_expired_maps_to_expired
    assert_equal "subscription.expired", normalized_type(notification("EXPIRED"))
  end

  def test_grace_period_expired_maps_to_expired
    assert_equal "subscription.expired", normalized_type(notification("GRACE_PERIOD_EXPIRED"))
  end

  def test_refund_maps_to_expired
    assert_equal "subscription.expired", normalized_type(notification("REFUND"))
  end

  def test_did_fail_to_renew_maps_to_updated
    assert_equal "subscription.updated", normalized_type(notification("DID_FAIL_TO_RENEW"))
  end

  def test_unknown_type_defaults_to_updated
    assert_equal "subscription.updated", normalized_type(notification("UNKNOWN_TYPE"))
  end

  def test_unknown_subtype_defaults_to_updated
    assert_equal "subscription.updated", normalized_type(notification("DID_CHANGE_RENEWAL_STATUS", "UNKNOWN_SUBTYPE"))
  end

  def test_status_mapping_for_active_types
    %w[subscription.created subscription.updated subscription.canceled].each do |type|
      assert_equal "active", STATUS_MAPPING[type], "Expected #{type} to map to active"
    end
  end

  def test_status_mapping_for_expired
    assert_equal "expired", STATUS_MAPPING["subscription.expired"]
  end

  private

  def notification(type, subtype = nil)
    RubyNative::IAP::Decodable::Notification.new(
      notification_type: type,
      subtype: subtype,
      notification_uuid: "uuid",
      bundle_id: "com.example",
      app_account_token: "token",
      product_id: "prod",
      original_transaction_id: "orig",
      transaction_id: "txn",
      purchase_date: Time.current,
      expires_date: 1.year.from_now,
      offer_type: nil,
      environment: "sandbox"
    )
  end
end
