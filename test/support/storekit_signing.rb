require "base64"
require "jwt"
require "openssl"
require "tempfile"

# A throwaway root, intermediate, and leaf in the shape Apple signs StoreKit
# payloads with: ES256, with the chain in the `x5c` header, leaf first.
class StoreKitSigning
  Issued = Struct.new(:certificate, :key)

  attr_reader :root, :intermediate, :leaf

  def initialize
    @serial = 0
    @root = issue("Test Root CA", ca: true)
    @intermediate = issue("Test Intermediate CA", ca: true, issuer: @root)
    @leaf = issue("Test Leaf", issuer: @intermediate)
  end

  def issue(common_name, issuer: nil, ca: false, not_before: Time.now - 3600, not_after: Time.now + 3600)
    key = OpenSSL::PKey::EC.generate("prime256v1")
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = (@serial += 1)
    certificate.subject = OpenSSL::X509::Name.parse("/CN=#{common_name}")
    certificate.issuer = issuer ? issuer.certificate.subject : certificate.subject
    certificate.public_key = key
    certificate.not_before = not_before
    certificate.not_after = not_after
    certificate.add_extension(
      OpenSSL::X509::Extension.new("basicConstraints", ca ? "CA:TRUE" : "CA:FALSE", true)
    )
    certificate.sign(issuer ? issuer.key : key, OpenSSL::Digest.new("SHA256"))
    Issued.new(certificate, key)
  end

  def x5c(chain = [leaf, intermediate, root])
    chain.map { |issued| Base64.strict_encode64(issued.certificate.to_der) }
  end

  def sign(payload, key: leaf.key, x5c: self.x5c)
    JWT.encode(payload, key, "ES256", {x5c: x5c}.compact)
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
end
