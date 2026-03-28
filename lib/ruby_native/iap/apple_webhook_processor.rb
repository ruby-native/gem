module RubyNative
  module IAP
    class AppleWebhookProcessor
      include Verifiable
      include Decodable
      include Normalizable

      def process(signed_payload)
        notification = parse_notification(signed_payload)
        intent = PurchaseIntent.find_by(uuid: notification.app_account_token)

        event = build_event(notification, intent)

        intent&.update!(status: :completed) if intent&.pending?

        RubyNative.fire_subscription_callbacks(event)
        event
      end

      private

      def build_event(notification, intent)
        type = normalized_type(notification)

        Event.new(
          type: type,
          status: STATUS_MAPPING[type] || "active",
          owner_token: intent&.customer_id,
          product_id: notification.product_id,
          original_transaction_id: notification.original_transaction_id,
          transaction_id: notification.transaction_id,
          purchase_date: notification.purchase_date,
          expires_date: notification.expires_date,
          environment: notification.environment,
          notification_uuid: notification.notification_uuid,
          success_path: intent&.success_path
        )
      end
    end
  end
end
