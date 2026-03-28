module RubyNative
  module IAP
    module Normalizable
      TYPE_MAPPING = {
        "SUBSCRIBED" => "subscription.created",
        "DID_RENEW" => "subscription.updated",
        "DID_CHANGE_RENEWAL_STATUS" => {
          "AUTO_RENEW_DISABLED" => "subscription.canceled",
          "AUTO_RENEW_ENABLED" => "subscription.updated"
        },
        "DID_CHANGE_RENEWAL_INFO" => {
          "UPGRADE" => "subscription.updated",
          "DOWNGRADE" => "subscription.updated"
        },
        "EXPIRED" => "subscription.expired",
        "DID_FAIL_TO_RENEW" => "subscription.updated",
        "GRACE_PERIOD_EXPIRED" => "subscription.expired",
        "REFUND" => "subscription.expired"
      }.freeze

      STATUS_MAPPING = {
        "subscription.created" => "active",
        "subscription.updated" => "active",
        "subscription.canceled" => "active",
        "subscription.expired" => "expired"
      }.freeze

      private

      def normalized_type(notification)
        mapping = TYPE_MAPPING[notification.notification_type]

        if mapping.is_a?(Hash)
          mapping[notification.subtype] || "subscription.updated"
        else
          mapping || "subscription.updated"
        end
      end
    end
  end
end
