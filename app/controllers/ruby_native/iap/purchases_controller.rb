module RubyNative
  module IAP
    class PurchasesController < ::ActionController::Base
      skip_forgery_protection

      def create
        intent = PurchaseIntent.create!(
          customer_id: params[:customer_id],
          product_id: params[:product_id],
          success_path: params[:success_path],
          environment: params[:environment] || "production"
        )

        render json: {uuid: intent.uuid, product_id: intent.product_id}
      end
    end
  end
end
