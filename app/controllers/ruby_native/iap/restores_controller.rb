module RubyNative
  module IAP
    class RestoresController < ::ActionController::Base
      include Verifiable
      include Decodable

      skip_forgery_protection

      def create
        return head :bad_request if params[:customer_id].blank?

        transactions = Array(params[:signed_transactions])
        return head :bad_request if transactions.empty?

        transactions.each do |signed_transaction|
          transaction = decode_and_verify_jws(signed_transaction)
          verify_bundle_id!(transaction["bundleId"])
          restore(transaction)
        end

        head :ok
      rescue VerificationError, JWT::DecodeError => e
        Rails.logger.warn "[RubyNative] Restore verification failed: #{e.message}"
        head :unprocessable_entity
      end

      private

      # The account being restored to comes from the purchase intent the
      # transaction was made against, never from `customer_id` in the request. A
      # signed transaction is only proof that Apple sold it, not proof of who is
      # asking, so honoring a caller-supplied id let one purchased subscription
      # be replayed to grant entitlement to any number of accounts.
      def restore(transaction)
        transaction_id = transaction["transactionId"]
        intent = PurchaseIntent.find_by(uuid: transaction["appAccountToken"])

        unless intent
          Rails.logger.warn "[RubyNative] Ignoring restored transaction #{transaction_id.inspect}: " \
            "no purchase intent matches its appAccountToken"
          return
        end

        if params[:customer_id] != intent.customer_id
          Rails.logger.warn "[RubyNative] Restoring transaction #{transaction_id.inspect} to " \
            "#{intent.customer_id.inspect} from its purchase intent, not the requested " \
            "#{params[:customer_id].inspect}"
        end

        # Apple reissues a transaction id on every renewal, so a restore of the
        # same one is a repeat and must not fire the callback again.
        return if dedup_available? && intent.restored_transaction_id == transaction_id

        intent.update!(intent_attributes(transaction))

        event = Event.new(
          type: "subscription.created",
          status: "active",
          owner_token: intent.customer_id,
          product_id: transaction["productId"],
          original_transaction_id: transaction["originalTransactionId"],
          transaction_id: transaction_id,
          purchase_date: parse_timestamp(transaction["purchaseDate"]),
          expires_date: parse_timestamp(transaction["expiresDate"]),
          environment: transaction["environment"]&.downcase,
          notification_uuid: SecureRandom.uuid,
          success_path: params[:success_path]
        )

        RubyNative.fire_subscription_callbacks(event)
      end

      # A restore is the recovery path for a purchase whose completion POST never
      # landed, so it settles the intent too. An unrecognized environment is
      # dropped rather than raising on the enum.
      def intent_attributes(transaction)
        attributes = {status: :completed}
        environment = transaction["environment"]&.downcase
        attributes[:environment] = environment if PurchaseIntent.environments.key?(environment)
        attributes[:restored_transaction_id] = transaction["transactionId"] if dedup_available?
        attributes
      end

      # Deduping needs a column that arrives in a migration, and an app can be on
      # this version of the gem before it has been run. Restoring to the right
      # account is the part that matters and needs no column, so a missing one
      # costs the repeat-callback guard and nothing else -- which is how restore
      # behaved before the column existed anyway. Writing to it regardless would
      # raise, and the app reports a restore as successful without reading the
      # response, so the customer would be told "Restored!" over a 500.
      def dedup_available?
        PurchaseIntent.column_names.include?("restored_transaction_id")
      end
    end
  end
end
