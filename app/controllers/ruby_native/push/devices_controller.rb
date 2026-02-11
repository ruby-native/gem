module RubyNative
  module Push
    class DevicesController < ::ApplicationController
      skip_forgery_protection

      def create
        device = current_user.push_devices.find_or_initialize_by(token: params[:token])
        device.update!(platform: params[:platform], name: params[:name])
        head :ok
      end
    end
  end
end
