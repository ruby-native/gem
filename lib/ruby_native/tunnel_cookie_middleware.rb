module RubyNative
  # Strips the `domain=` attribute from Set-Cookie headers when the request
  # comes through a Cloudflare tunnel (*.trycloudflare.com).
  #
  # Many Rails apps configure `domain: :all, tld_length: 2` on their session
  # store. Through a tunnel this resolves to `.trycloudflare.com`, a public
  # suffix domain. Browsers and WKWebView silently reject those cookies,
  # breaking authentication.
  #
  # Removing the domain attribute lets the cookie scope to the exact tunnel
  # hostname (e.g. `abc-123.trycloudflare.com`) so it persists normally.
  class TunnelCookieMiddleware
    TUNNEL_HOST_PATTERN = /\.trycloudflare\.com\z/

    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)

      if tunnel_request?(env) && headers["set-cookie"]
        strip_cookie_domain!(headers)
      end

      [status, headers, body]
    end

    private

    def tunnel_request?(env)
      host = env["HTTP_HOST"] || env["SERVER_NAME"] || ""
      host.match?(TUNNEL_HOST_PATTERN)
    end

    def strip_cookie_domain!(headers)
      raw = headers["set-cookie"]
      cookies = raw.is_a?(Array) ? raw : raw.split("\n")

      headers["set-cookie"] = cookies.map { |cookie|
        cookie.gsub(/;\s*domain=[^;]*/i, "")
      }.join("\n")
    end
  end
end
