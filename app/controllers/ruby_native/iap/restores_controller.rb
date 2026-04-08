module RubyNative
  module IAP
    class RestoresController < ::ActionController::Base
      include Verifiable
      include Decodable

      skip_forgery_protection

      def create
        customer_id = params[:customer_id]
        return head :bad_request if customer_id.blank?

        transactions = Array(params[:signed_transactions])
        return head :bad_request if transactions.empty?

        transactions.each do |signed_transaction|
          transaction = decode_and_verify_jws(signed_transaction)

          event = Event.new(
            type: "subscription.created",
            status: "active",
            owner_token: customer_id,
            product_id: transaction["productId"],
            original_transaction_id: transaction["originalTransactionId"],
            transaction_id: transaction["transactionId"],
            purchase_date: parse_timestamp(transaction["purchaseDate"]),
            expires_date: parse_timestamp(transaction["expiresDate"]),
            environment: transaction["environment"]&.downcase,
            notification_uuid: SecureRandom.uuid,
            success_path: params[:success_path]
          )

          RubyNative.fire_subscription_callbacks(event)
        end

        head :ok
      rescue VerificationError, JWT::DecodeError => e
        Rails.logger.warn "[RubyNative] Restore verification failed: #{e.message}"
        head :unprocessable_entity
      end
    end
  end
end
