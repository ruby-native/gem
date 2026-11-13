module RubyNative
  module IAP
    class VerificationError < StandardError; end

    module Verifiable
      APPLE_ROOT_CERT_PATH = File.join(__dir__, "..", "certs", "AppleRootCA-G3.pem")

      # Extensions Apple puts on the certificates that sign App Store payloads.
      RECEIPT_SIGNING_LEAF_OID = "1.2.840.113635.100.6.11.1"
      WWDR_INTERMEDIATE_OID = "1.2.840.113635.100.6.2.1"

      CHAIN_LENGTH = 3

      def self.warn_missing_bundle_id
        return if @warned_missing_bundle_id

        @warned_missing_bundle_id = true
        Rails.logger.warn(
          "[RubyNative] Set ios.bundle_id in config/ruby_native.yml so in-app purchases are checked against your app."
        )
      end

      private

      # `at` is the time the chain has to be valid at, so a payload signed
      # before its certificate expired still verifies.
      def verify_certificate_chain(x5c_certs, at: Time.now)
        raise VerificationError, "Missing x5c certificates" unless x5c_certs.is_a?(Array) && !x5c_certs.empty?
        unless x5c_certs.size == CHAIN_LENGTH
          raise VerificationError, "Expected #{CHAIN_LENGTH} x5c certificates, got #{x5c_certs.size}"
        end

        leaf, intermediate, root = x5c_certs.map { |cert_base64| parse_certificate(cert_base64) }

        unless root.to_der == apple_root_certificate.to_der
          raise VerificationError, "Root certificate does not match Apple's known root"
        end
        unless extension?(leaf, RECEIPT_SIGNING_LEAF_OID)
          raise VerificationError, "Leaf certificate is not an App Store signing certificate"
        end
        unless extension?(intermediate, WWDR_INTERMEDIATE_OID)
          raise VerificationError, "Intermediate certificate is not an Apple WWDR certificate"
        end

        verify_certificate_path(leaf, intermediate, at)

        leaf.public_key
      end

      def parse_certificate(cert_base64)
        raise VerificationError, "x5c certificate is not a string" unless cert_base64.is_a?(String)

        OpenSSL::X509::Certificate.new(Base64.decode64(cert_base64))
      rescue OpenSSL::X509::CertificateError => error
        raise VerificationError, "x5c certificate could not be parsed: #{error.message}"
      end

      def extension?(certificate, oid)
        certificate.extensions.any? { |extension| extension.oid == oid }
      end

      # Only the bundled root is trusted. The root the payload presents is never added to the store.
      def verify_certificate_path(leaf, intermediate, at)
        store = OpenSSL::X509::Store.new
        store.add_cert(apple_root_certificate)
        store.time = at

        return if store.verify(leaf, [intermediate])

        raise VerificationError, "Certificate chain verification failed: #{store.error_string}"
      rescue RangeError
        raise VerificationError, "Certificate chain cannot be verified at #{at}"
      end

      def verify_bundle_id!(bundle_id)
        expected = RubyNative.config&.dig(:ios, :bundle_id)

        if expected.blank?
          Verifiable.warn_missing_bundle_id
        elsif bundle_id != expected.to_s
          raise VerificationError, "bundleId does not match ios.bundle_id in config/ruby_native.yml"
        end
      end

      def apple_root_certificate
        @apple_root_certificate ||= OpenSSL::X509::Certificate.new(
          File.read(APPLE_ROOT_CERT_PATH)
        )
      end
    end
  end
end
