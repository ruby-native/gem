require "test_helper"

class RubyNative::IAP::PurchaseIntentTest < Minitest::Test
  def setup
    RubyNative::IAP::PurchaseIntent.delete_all
  end

  def test_generates_uuid_on_create
    intent = RubyNative::IAP::PurchaseIntent.create!(customer_id: "user_1")
    assert intent.uuid.present?
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, intent.uuid)
  end

  def test_does_not_overwrite_existing_uuid
    intent = RubyNative::IAP::PurchaseIntent.create!(customer_id: "user_1", uuid: "custom-uuid")
    assert_equal "custom-uuid", intent.uuid
  end

  def test_defaults_to_pending_status
    intent = RubyNative::IAP::PurchaseIntent.create!(customer_id: "user_1")
    assert intent.pending?
  end

  def test_status_enum
    intent = RubyNative::IAP::PurchaseIntent.create!(customer_id: "user_1")
    intent.update!(status: :completed)
    assert intent.completed?
  end

  def test_environment_enum
    intent = RubyNative::IAP::PurchaseIntent.create!(customer_id: "user_1", environment: :sandbox)
    assert intent.sandbox?

    intent.update!(environment: :xcode)
    assert intent.xcode?
  end

  def test_requires_customer_id
    intent = RubyNative::IAP::PurchaseIntent.new
    refute intent.valid?
    assert intent.errors[:customer_id].any?
  end

  def test_stores_product_id_and_success_path
    intent = RubyNative::IAP::PurchaseIntent.create!(
      customer_id: "user_1",
      product_id: "com.example.annual",
      success_path: "/dashboard"
    )

    intent.reload
    assert_equal "com.example.annual", intent.product_id
    assert_equal "/dashboard", intent.success_path
  end
end
