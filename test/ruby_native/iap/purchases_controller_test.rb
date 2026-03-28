require "test_helper"

class RubyNative::IAP::PurchasesControllerTest < ActionDispatch::IntegrationTest
  def setup
    RubyNative::IAP::PurchaseIntent.delete_all
  end

  def test_creates_purchase_intent_and_returns_uuid
    post "/native/iap/purchases", params: {
      customer_id: "user_42",
      product_id: "com.example.annual",
      success_path: "/dashboard"
    }

    assert_response :ok

    body = JSON.parse(response.body)
    assert body["uuid"].present?
    assert_equal "com.example.annual", body["product_id"]

    intent = RubyNative::IAP::PurchaseIntent.last
    assert_equal "user_42", intent.customer_id
    assert_equal "/dashboard", intent.success_path
    assert intent.pending?
  end

  def test_defaults_environment_to_production
    post "/native/iap/purchases", params: {customer_id: "user_1"}

    intent = RubyNative::IAP::PurchaseIntent.last
    assert intent.production?
  end

  def test_accepts_environment_param
    post "/native/iap/purchases", params: {customer_id: "user_1", environment: "sandbox"}

    intent = RubyNative::IAP::PurchaseIntent.last
    assert intent.sandbox?
  end
end
