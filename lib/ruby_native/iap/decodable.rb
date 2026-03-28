require "jwt"

module RubyNative
  module IAP
    module Decodable
      Notification = Data.define(
        :notification_type,
        :subtype,
        :notification_uuid,
        :bundle_id,
        :app_account_token,
        :product_id,
        :original_transaction_id,
        :transaction_id,
        :purchase_date,
        :expires_date,
        :offer_type,
        :environment
      )

      private

      def parse_notification(signed_payload)
        payload = decode_and_verify_jws(signed_payload)
        transaction_info = decode_and_verify_jws(payload["data"]["signedTransactionInfo"])

        Notification.new(
          notification_type: payload["notificationType"],
          subtype: payload["subtype"],
          notification_uuid: payload["notificationUUID"],
          bundle_id: payload["data"]["bundleId"],
          app_account_token: transaction_info["appAccountToken"],
          product_id: transaction_info["productId"],
          original_transaction_id: transaction_info["originalTransactionId"],
          transaction_id: transaction_info["transactionId"],
          purchase_date: parse_timestamp(transaction_info["purchaseDate"]),
          expires_date: parse_timestamp(transaction_info["expiresDate"]),
          offer_type: transaction_info["offerType"],
          environment: payload["data"]["environment"]&.downcase
        )
      end

      def decode_and_verify_jws(jws)
        JWT.decode(jws, nil, true, algorithm: "ES256") { |header|
          verify_certificate_chain(header["x5c"])
        }.first
      end

      def parse_timestamp(milliseconds)
        return nil if milliseconds.nil?
        Time.at(milliseconds / 1000.0).utc
      end
    end
  end
end
