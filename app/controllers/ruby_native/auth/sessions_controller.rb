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

        # Store cookies server-side for the middleware to inject on the
        # next request. This avoids Set-Cookie headers entirely, which
        # CDNs like Cloudflare can strip from responses.
        restore_token = SecureRandom.urlsafe_base64(32)
        Rails.cache.write(
          "ruby_native:oauth_session:#{restore_token}",
          cookies,
          expires_in: 1.minute
        )

        separator = redirect_url.include?("?") ? "&" : "?"
        target = "#{redirect_url}#{separator}_rn_session=#{restore_token}"

        Rails.logger.info { "[RubyNative] Cached #{cookies.size} cookies, redirecting to #{target}" }
        redirect_to target, allow_other_host: true
      end
    end
  end
end
