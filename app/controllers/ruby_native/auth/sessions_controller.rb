module RubyNative
  module Auth
    class SessionsController < ::ActionController::Base
      def show
        data = OAuthMiddleware.read_token(params[:token])

        unless data
          Rails.logger.debug { "[RubyNative] OAuth token exchange failed: invalid or expired token" }
          head :unauthorized
          return
        end

        cookies = data[:cookies] || []
        redirect_url = data[:redirect_url]

        Rails.logger.info { "[RubyNative] OAuth token exchanged, #{cookies.size} cookies, redirect to #{redirect_url}" }
        render json: {cookies: cookies, redirect_url: redirect_url}
      end
    end
  end
end
