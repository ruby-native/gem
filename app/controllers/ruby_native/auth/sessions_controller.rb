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

        if data[:cookies].present?
          response.headers["set-cookie"] = data[:cookies].join("\n")
        end

        Rails.logger.debug { "[RubyNative] OAuth token exchanged, redirecting to #{data[:redirect_url]}" }
        render json: {redirect_url: data[:redirect_url]}
      end
    end
  end
end
