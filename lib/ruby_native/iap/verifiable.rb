module RubyNative
  module IAP
    class VerificationError < StandardError; end

    module Verifiable
      APPLE_ROOT_CERT_PATH = File.join(__dir__, "..", "certs", "AppleRootCA-G3.cer")

      private

      def verify_certificate_chain(x5c_certs)
        raise VerificationError, "Missing x5c certificates" if x5c_certs.nil? || x5c_certs.empty?

        certs = x5c_certs.map do |cert_base64|
          OpenSSL::X509::Certificate.new(Base64.decode64(cert_base64))
        end

        unless certs.last.to_der == apple_root_certificate.to_der
          raise VerificationError, "Root certificate does not match Apple's known root"
        end

        certs.each_cons(2) do |child, parent|
          unless child.verify(parent.public_key)
            raise VerificationError, "Certificate chain verification failed"
          end
        end

        certs.first.public_key
      end

      def apple_root_certificate
        @apple_root_certificate ||= OpenSSL::X509::Certificate.new(
          File.read(APPLE_ROOT_CERT_PATH)
        )
      end
    end
  end
end
