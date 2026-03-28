module RubyNative
  module IAP
    class CompletionsController < ::ActionController::Base
      skip_forgery_protection

      def create
        return head :not_found unless Rails.env.local?

        intent = PurchaseIntent.find_by!(uuid: params[:uuid])
        intent.update!(status: :completed, environment: :xcode)

        event = Event.new(
          type: "subscription.created",
          status: "active",
          owner_token: intent.customer_id,
          product_id: intent.product_id,
          original_transaction_id: "xcode_#{intent.uuid}",
          transaction_id: "xcode_#{intent.uuid}",
          purchase_date: Time.current,
          expires_date: 1.year.from_now,
          environment: "xcode",
          notification_uuid: SecureRandom.uuid,
          success_path: intent.success_path
        )

        RubyNative.fire_subscription_callbacks(event)
        head :ok
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end
    end
  end
end
