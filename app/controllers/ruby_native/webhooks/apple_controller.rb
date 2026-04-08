module RubyNative
  module Webhooks
    class AppleController < ::ActionController::Base
      skip_forgery_protection

      def create
        payload = JSON.parse(request.raw_post)
        signed_payload = payload["signedPayload"]
        return head :ok unless signed_payload

        # TEST notifications from Apple have no transaction data to process.
        decoded = JWT.decode(signed_payload, nil, false).first
        return head :ok if decoded["notificationType"] == "TEST"

        processor = RubyNative::IAP::AppleWebhookProcessor.new
        processor.process(signed_payload)

        head :ok
      rescue JSON::ParserError
        head :bad_request
      rescue RubyNative::IAP::VerificationError, JWT::DecodeError => e
        Rails.logger.error "[RubyNative] Apple webhook verification failed: #{e.message}"
        head :unprocessable_entity
      rescue => e
        Rails.logger.error "[RubyNative] Apple webhook error: #{e.message}"
        head :internal_server_error
      end
    end
  end
end
