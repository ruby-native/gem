module RubyNative
  module IAP
    class PurchaseIntent < ::ActiveRecord::Base
      self.table_name = "ruby_native_purchase_intents"

      before_create :generate_uuid

      enum :status, {pending: "pending", completed: "completed"}
      enum :environment, {sandbox: "sandbox", production: "production", xcode: "xcode"}

      validates :customer_id, presence: true

      private

      def generate_uuid
        self.uuid ||= SecureRandom.uuid
      end
    end
  end
end
