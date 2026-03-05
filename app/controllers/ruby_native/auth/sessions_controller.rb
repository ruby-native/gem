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

        # Prevent the session middleware from appending its own (empty)
        # session cookie, which would overwrite the authenticated one.
        request.session_options[:skip] = true

        cookies = data[:cookies] || []

        if cookies.present?
          response.headers["set-cookie"] = cookies.join("\n")
        end

        Rails.logger.info { "[RubyNative] OAuth token exchanged with #{cookies.size} cookies, redirecting to #{data[:redirect_url]}" }
        redirect_to data[:redirect_url], allow_other_host: true
      end
    end
  end
end
