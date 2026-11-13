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

  def test_a_chain_of_two_certificates_is_rejected
    x5c = @chain.x5c([@chain.leaf, @chain.root])

    assert_chain_rejected @chain, "Expected 3 x5c certificates", x5c: x5c
  end

  def test_a_chain_of_four_certificates_is_rejected
    x5c = @chain.x5c([@chain.leaf, @chain.intermediate, @chain.intermediate, @chain.root])

    assert_chain_rejected @chain, "Expected 3 x5c certificates", x5c: x5c
  end

  def test_an_x5c_entry_that_is_not_a_certificate_is_rejected
    x5c = [Base64.strict_encode64("not a certificate"), *@chain.x5c.drop(1)]

    assert_chain_rejected @chain, "could not be parsed", x5c: x5c
  end

  def test_an_x5c_entry_that_is_not_a_string_is_rejected
    assert_chain_rejected @chain, "not a string", x5c: [1, *@chain.x5c.drop(1)]
  end

  def test_a_leaf_without_the_app_store_signing_extension_is_rejected
    assert_chain_rejected StoreKitSigning.new(leaf: {marker: nil}), "Leaf certificate"
  end

  def test_an_intermediate_without_the_wwdr_extension_is_rejected
    assert_chain_rejected StoreKitSigning.new(intermediate: {marker: nil}), "Intermediate certificate"
  end

  def test_an_intermediate_that_is_not_a_certificate_authority_is_rejected
    assert_chain_rejected StoreKitSigning.new(intermediate: {ca: false}), "Certificate chain verification failed"
  end

  # --- Validity at the signed date ---

  def test_a_leaf_that_has_since_expired_is_accepted_for_a_payload_signed_while_it_was_valid
    chain = StoreKitSigning.new(leaf: {not_before: days_ago(800), not_after: days_ago(70)})
    payload = PAYLOAD.merge("signedDate" => milliseconds(days_ago(100)))

    chain.trusted do
      assert_equal payload, verify(chain.sign(payload))
    end
  end

  def test_a_leaf_expired_at_the_signed_date_is_rejected
    chain = StoreKitSigning.new(leaf: {not_before: days_ago(800), not_after: days_ago(70)})

    assert_chain_rejected chain, "certificate has expired", payload: {"signedDate" => milliseconds(days_ago(10))}
  end

  def test_a_leaf_not_yet_valid_at_the_signed_date_is_rejected
    chain = StoreKitSigning.new(leaf: {not_before: days_ago(800), not_after: days_ago(70)})

    assert_chain_rejected chain, "not yet valid", payload: {"signedDate" => milliseconds(days_ago(900))}
  end

  def test_a_payload_without_a_signed_date_is_checked_against_the_current_time
    chain = StoreKitSigning.new(leaf: {not_before: days_ago(800), not_after: days_ago(70)})

    assert_chain_rejected chain, "certificate has expired"
  end

  def test_a_signed_date_that_is_not_a_number_falls_back_to_the_current_time
    chain = StoreKitSigning.new(leaf: {not_before: days_ago(800), not_after: days_ago(70)})

    assert_chain_rejected chain, "certificate has expired", payload: {"signedDate" => "2026-01-01"}
    @chain.trusted do
      assert_equal({"signedDate" => "2026-01-01"}, verify(@chain.sign({"signedDate" => "2026-01-01"})))
    end
  end

  def test_a_signed_date_too_large_to_be_a_time_is_rejected
    assert_chain_rejected @chain, "cannot be verified", payload: {"signedDate" => 1e30}
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

  def assert_chain_rejected(chain, message, payload: PAYLOAD, **signing)
    chain.trusted do
      error = assert_raises(RubyNative::IAP::VerificationError) { verify(chain.sign(payload, **signing)) }

      assert_match message, error.message
    end
  end

  def days_ago(days)
    Time.now - days * 24 * 3600
  end

  def milliseconds(time)
    (time.to_f * 1000).to_i
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
