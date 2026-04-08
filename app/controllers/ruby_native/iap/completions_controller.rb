module RubyNative
  module IAP
    class CompletionsController < ::ActionController::Base
      include Verifiable
      include Decodable

      skip_forgery_protection

      def create
        intent = PurchaseIntent.find_by!(uuid: params[:uuid])
        return head :ok if intent.completed?

        transaction = verify_transaction!(intent)

        intent.update!(status: :completed, environment: transaction["environment"]&.downcase)

        event = Event.new(
          type: "subscription.created",
          status: "active",
          owner_token: intent.customer_id,
          product_id: transaction["productId"],
          original_transaction_id: transaction["originalTransactionId"],
          transaction_id: transaction["transactionId"],
          purchase_date: parse_timestamp(transaction["purchaseDate"]),
          expires_date: parse_timestamp(transaction["expiresDate"]),
          environment: transaction["environment"]&.downcase,
          notification_uuid: SecureRandom.uuid,
          success_path: intent.success_path
        )

        RubyNative.fire_subscription_callbacks(event)
        head :ok
      rescue ActiveRecord::RecordNotFound
        head :not_found
      rescue VerificationError, JWT::DecodeError => e
        Rails.logger.warn "[RubyNative] Completion verification failed: #{e.message}"
        head :unprocessable_entity
      end

      private

      def verify_transaction!(intent)
        signed_transaction = params[:signed_transaction]

        if signed_transaction.present?
          transaction = decode_and_verify_jws(signed_transaction)
          if transaction["appAccountToken"] != intent.uuid
            raise VerificationError, "appAccountToken does not match intent UUID"
          end
          transaction
        elsif Rails.env.local?
          # Allow unsigned completions for Xcode StoreKit testing in development.
          {
            "productId" => intent.product_id,
            "originalTransactionId" => "xcode_#{intent.uuid}",
            "transactionId" => "xcode_#{intent.uuid}",
            "purchaseDate" => (Time.current.to_f * 1000).to_i,
            "expiresDate" => (1.year.from_now.to_f * 1000).to_i,
            "environment" => "Xcode"
          }
        else
          raise VerificationError, "Missing signed_transaction"
        end
      end
    end
  end
end
