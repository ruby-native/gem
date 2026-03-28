module RubyNative
  module Webhooks
    class AppleController < ::ActionController::Base
      skip_forgery_protection

      def create
        payload = JSON.parse(request.raw_post)
        signed_payload = payload["signedPayload"]

        processor = RubyNative::IAP::AppleWebhookProcessor.new
        processor.process(signed_payload)

        head :ok
      rescue JSON::ParserError
        head :bad_request
      rescue RubyNative::IAP::VerificationError => e
        Rails.logger.error "[RubyNative] Apple webhook verification failed: #{e.message}"
        head :unauthorized
      rescue => e
        Rails.logger.error "[RubyNative] Apple webhook error: #{e.message}"
        head :ok
      end
    end
  end
end
