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

        redirect_url = data[:redirect_url]
        Rails.logger.info { "[RubyNative] OAuth token exchanged with #{cookies.size} cookies, redirecting to #{redirect_url}" }

        # Render a 200 HTML page instead of a 302 redirect. CDNs like
        # Cloudflare can strip Set-Cookie headers from redirect responses,
        # preventing WKWebView from applying them. A 200 response guarantees
        # cookies are set before the meta refresh navigates to the target.
        render html: redirect_page(redirect_url).html_safe, status: :ok
      end

      private

      def redirect_page(url)
        escaped = ERB::Util.html_escape(url)
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head><meta http-equiv="refresh" content="0;url=#{escaped}"></head>
          <body></body>
          </html>
        HTML
      end
    end
  end
end
