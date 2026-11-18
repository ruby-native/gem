require "base64"
require "jwt"
require "openssl"
require "tempfile"

# A throwaway root, intermediate, and leaf in the shape Apple signs StoreKit
# payloads with: ES256, with the chain in the `x5c` header, leaf first.
class StoreKitSigning
  LEAF_MARKER = "1.2.840.113635.100.6.11.1"
  INTERMEDIATE_MARKER = "1.2.840.113635.100.6.2.1"

  YEAR = 365 * 24 * 3600

  Issued = Struct.new(:certificate, :key)

  attr_reader :root, :intermediate, :leaf

  # `intermediate:` and `leaf:` take the same options as `issue`, to change one property of the chain.
  def initialize(intermediate: {}, leaf: {})
    @serial = 0
    @root = issue("Test Root CA", ca: true, **valid_for(20 * YEAR))
    @intermediate = issue(
      "Test Intermediate CA",
      issuer: @root, ca: true, marker: INTERMEDIATE_MARKER, **valid_for(10 * YEAR), **intermediate
    )
    @leaf = issue("Test Leaf", issuer: @intermediate, marker: LEAF_MARKER, **leaf)
  end

  def issue(common_name, issuer: nil, ca: false, marker: nil, not_before: Time.now - YEAR, not_after: Time.now + YEAR)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = (@serial += 1)
    certificate.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}")
    certificate.issuer = issuer ? issuer.certificate.subject : certificate.subject
    certificate.public_key = key
    certificate.not_before = not_before
    certificate.not_after = not_after
    extensions(ca: ca, marker: marker).each { |extension| certificate.add_extension(extension) }
    certificate.sign(issuer ? issuer.key : key, OpenSSL::Digest.new("SHA256"))
    Issued.new(certificate, key)
  end

  def x5c(chain = [leaf, intermediate, root])
    chain.map { |issued| Base64.strict_encode64(issued.certificate.to_der) }
  end

  def sign(payload, key: leaf.key, x5c: self.x5c)
    JWT.encode(payload, key, "ES256", {x5c: x5c}.compact)
  end

  # The bundle ID verified payloads are checked against, as `ios.bundle_id` in the config.
  def self.with_bundle_id(bundle_id)
    RubyNative.config[:ios] = {bundle_id: bundle_id}
    yield
  ensure
    RubyNative.load_config
  end

  # Points the verifier at this chain's root in place of Apple's.
  def trusted
    Tempfile.create(["root", ".pem"]) do |file|
      file.write(root.certificate.to_pem)
      file.flush
      StoreKitSigning.swap_root_path(file.path) { yield }
    end
  end

  def self.swap_root_path(path)
    verifiable = RubyNative::IAP::Verifiable
    original = verifiable.send(:remove_const, :APPLE_ROOT_CERT_PATH)
    verifiable.const_set(:APPLE_ROOT_CERT_PATH, path)
    yield
  ensure
    verifiable.send(:remove_const, :APPLE_ROOT_CERT_PATH)
    verifiable.const_set(:APPLE_ROOT_CERT_PATH, original)
  end

  private

  def valid_for(seconds)
    {not_before: Time.now - seconds, not_after: Time.now + seconds}
  end

  def extensions(ca:, marker:)
    factory = OpenSSL::X509::ExtensionFactory.new
    extensions = [
      factory.create_extension("basicConstraints", ca ? "CA:TRUE" : "CA:FALSE", true),
      factory.create_extension("keyUsage", ca ? "keyCertSign,cRLSign" : "digitalSignature", true)
    ]
    extensions << OpenSSL::X509::Extension.new(marker, OpenSSL::ASN1::Null.new(nil).to_der, false) if marker
    extensions
  end
end
