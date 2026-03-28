module RubyNative
  module IAP
    class Event
      attr_reader :type, :status, :owner_token, :product_id,
                  :original_transaction_id, :transaction_id,
                  :purchase_date, :expires_date, :environment,
                  :notification_uuid, :success_path

      def initialize(type:, status:, owner_token:, product_id:, original_transaction_id:,
                     transaction_id:, purchase_date:, expires_date:, environment:,
                     notification_uuid:, success_path:)
        @type = type
        @status = status
        @owner_token = owner_token
        @product_id = product_id
        @original_transaction_id = original_transaction_id
        @transaction_id = transaction_id
        @purchase_date = purchase_date
        @expires_date = expires_date
        @environment = environment
        @notification_uuid = notification_uuid
        @success_path = success_path
      end

      def active?
        status == "active"
      end

      def expired?
        status == "expired"
      end

      def created?
        type == "subscription.created"
      end

      def canceled?
        type == "subscription.canceled"
      end
    end
  end
end
