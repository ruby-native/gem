require "test_helper"
require "support/storekit_signing"

class RubyNative::IAP::VerificationTest < Minitest::Test
  APPLE_ROOT_CA_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179"

  class Verifier
    include RubyNative::IAP::Verifiable
    include RubyNative::IAP::Decodable

    public :decode_and_verify_jws, :parse_notification
  end

  PAYLOAD = {"transactionId" => "2000000000000001", "productId" => "com.example.annual"}.freeze

  def setup
    @chain = StoreKitSigning.new
  end

  # --- The trusted root ---

  def test_the_bundled_root_is_apple_root_ca_g3
    root = OpenSSL::X509::Certificate.new(File.read(RubyNative::IAP::Verifiable::APPLE_ROOT_CERT_PATH))

    assert_equal APPLE_ROOT_CA_G3_SHA256, OpenSSL::Digest::SHA256.hexdigest(root.to_der)
  end

  def test_a_chain_that_does_not_end_in_the_apple_root_is_rejected_by_default
    error = assert_raises(RubyNative::IAP::VerificationError) { verify(@chain.sign(PAYLOAD)) }

    assert_match "Root certificate does not match", error.message
  end

  # --- Certificate chain ---

  def test_a_valid_chain_and_signature_returns_the_payload
    @chain.trusted do
      assert_equal PAYLOAD, verify(@chain.sign(PAYLOAD))
    end
  end

  def test_a_chain_from_another_root_is_rejected
    stranger = StoreKitSigning.new

    @chain.trusted do
      error = assert_raises(RubyNative::IAP::VerificationError) { verify(stranger.sign(PAYLOAD)) }

      assert_match "Root certificate does not match", error.message
    end
  end

  def test_another_chain_with_the_trusted_root_appended_is_rejected
    stranger = StoreKitSigning.new
    x5c = stranger.x5c([stranger.leaf, stranger.intermediate, @chain.root])

    @chain.trusted do
      error = assert_raises(RubyNative::IAP::VerificationError) { verify(stranger.sign(PAYLOAD, x5c: x5c)) }

      assert_match "Certificate chain verification failed", error.message
    end
  end

  def test_a_leaf_the_intermediate_did_not_issue_is_rejected
    stranger = StoreKitSigning.new
    x5c = @chain.x5c([stranger.leaf, @chain.intermediate, @chain.root])

    @chain.trusted do
      error = assert_raises(RubyNative::IAP::VerificationError) do
        verify(stranger.sign(PAYLOAD, x5c: x5c))
      end

      assert_match "Certificate chain verification failed", error.message
    end
  end

  def test_a_missing_x5c_header_is_rejected
    @chain.trusted do
      error = assert_raises(RubyNative::IAP::VerificationError) { verify(@chain.sign(PAYLOAD, x5c: nil)) }

      assert_match "Missing x5c", error.message
    end
  end

  def test_an_empty_x5c_header_is_rejected
    @chain.trusted do
      assert_raises(RubyNative::IAP::VerificationError) { verify(@chain.sign(PAYLOAD, x5c: [])) }
    end
  end

  # --- Signature ---

  def test_a_payload_altered_after_signing_is_rejected
    header, _payload, signature = @chain.sign(PAYLOAD).split(".")
    altered = Base64.urlsafe_encode64(PAYLOAD.merge("productId" => "com.example.lifetime").to_json, padding: false)

    @chain.trusted do
      assert_raises(JWT::VerificationError) { verify([header, altered, signature].join(".")) }
    end
  end

  def test_a_signature_from_a_key_that_is_not_the_leaf_key_is_rejected
    other_key = OpenSSL::PKey::EC.generate("prime256v1")

    @chain.trusted do
      assert_raises(JWT::VerificationError) { verify(@chain.sign(PAYLOAD, key: other_key)) }
    end
  end

  def test_an_unsigned_token_carrying_a_valid_chain_is_rejected
    unsigned = JWT.encode(PAYLOAD, nil, "none", {x5c: @chain.x5c})

    @chain.trusted do
      assert_raises(JWT::DecodeError) { verify(unsigned) }
    end
  end

  def test_a_token_signed_with_another_algorithm_is_rejected
    hmac = JWT.encode(PAYLOAD, @chain.leaf.certificate.to_pem, "HS256", {x5c: @chain.x5c})

    @chain.trusted do
      assert_raises(JWT::DecodeError) { verify(hmac) }
    end
  end

  # --- Server notifications ---

  def test_a_notification_is_parsed_from_its_signed_payload_and_signed_transaction
    @chain.trusted do
      notification = Verifier.new.parse_notification(@chain.sign(notification_payload(@chain.sign(transaction_info))))

      assert_equal "DID_RENEW", notification.notification_type
      assert_equal "notification-uuid", notification.notification_uuid
      assert_equal "com.example.app", notification.bundle_id
      assert_equal "sandbox", notification.environment
      assert_equal "intent-uuid", notification.app_account_token
      assert_equal "com.example.annual", notification.product_id
      assert_equal "2000000000000001", notification.transaction_id
      assert_equal Time.utc(2026, 1, 1), notification.purchase_date
      assert_equal Time.utc(2027, 1, 1), notification.expires_date
    end
  end

  def test_a_notification_whose_transaction_is_signed_by_another_chain_is_rejected
    stranger = StoreKitSigning.new

    @chain.trusted do
      assert_raises(RubyNative::IAP::VerificationError) do
        Verifier.new.parse_notification(@chain.sign(notification_payload(stranger.sign(transaction_info))))
      end
    end
  end

  private

  def verify(jws)
    Verifier.new.decode_and_verify_jws(jws)
  end

  def notification_payload(signed_transaction_info)
    {
      "notificationType" => "DID_RENEW",
      "notificationUUID" => "notification-uuid",
      "data" => {
        "bundleId" => "com.example.app",
        "environment" => "Sandbox",
        "signedTransactionInfo" => signed_transaction_info
      }
    }
  end

  def transaction_info
    {
      "appAccountToken" => "intent-uuid",
      "productId" => "com.example.annual",
      "originalTransactionId" => "2000000000000000",
      "transactionId" => "2000000000000001",
      "purchaseDate" => Time.utc(2026, 1, 1).to_i * 1000,
      "expiresDate" => Time.utc(2027, 1, 1).to_i * 1000
    }
  end
end
