module RubyNative
  class OAuthMiddleware
    COOKIE_NAME = "_ruby_native_oauth"

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      started_oauth = oauth_start_request?(request)
      callback_scheme = request.params["callback_scheme"] if started_oauth

      status, headers, body = @app.call(env)

      if started_oauth && callback_scheme.present? && redirect?(status)
        Rails.logger.debug { "[RubyNative] OAuth started for #{request.path}, setting tracking cookie" }
        set_cookie(headers, callback_scheme)
      end

      stored_scheme = read_cookie(request)

      if stored_scheme && redirect?(status)
        location = headers["location"] || headers["Location"]

        if auth_failure?(location)
          Rails.logger.info { "[RubyNative] OAuth failed, redirecting to native app" }
          delete_cookie(headers)
          return redirect_to_native(stored_scheme, error: true)
        end

        if internal_redirect?(request, location)
          token = build_token(headers, location)
          Rails.logger.info { "[RubyNative] OAuth succeeded, redirecting to native app" }
          delete_cookie(headers)
          return redirect_to_native(stored_scheme, token: token)
        end
      end

      [status, headers, body]
    end

    def self.encryptor
      @encryptor ||= begin
        key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
          .generate_key("ruby_native_oauth", ActiveSupport::MessageEncryptor.key_len)
        ActiveSupport::MessageEncryptor.new(key)
      end
    end

    def self.build_token(cookies:, redirect_url:)
      encryptor.encrypt_and_sign(
        {cookies: cookies, redirect_url: redirect_url},
        expires_in: 5.minutes,
        purpose: "ruby_native_oauth"
      )
    end

    def self.read_token(token)
      data = encryptor.decrypt_and_verify(token, purpose: "ruby_native_oauth")
      data&.symbolize_keys
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    private

    def oauth_start_request?(request)
      return false unless oauth_paths.any? { |p| request.path == p }
      request.params["ruby_native"] == "1"
    end

    def set_cookie(headers, callback_scheme)
      signed = verifier.generate(callback_scheme)
      Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, {
        value: signed,
        path: "/",
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        max_age: 300
      })
    end

    def read_cookie(request)
      signed_value = request.cookies[COOKIE_NAME]
      return nil unless signed_value.present?
      verifier.verified(signed_value)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def delete_cookie(headers)
      Rack::Utils.delete_set_cookie_header!(headers, COOKIE_NAME, path: "/")
    end

    def verifier
      @verifier ||= ActiveSupport::MessageVerifier.new(
        Rails.application.secret_key_base,
        digest: "SHA256",
        purpose: "ruby_native_oauth"
      )
    end

    def redirect?(status)
      (300..399).cover?(status)
    end

    def auth_failure?(location)
      return false unless location
      URI.parse(location).path == "/auth/failure"
    rescue URI::InvalidURIError
      false
    end

    def internal_redirect?(request, location)
      return false unless location
      uri = URI.parse(location)
      uri.host.nil? || uri.host == request.host
    rescue URI::InvalidURIError
      false
    end

    def build_token(headers, redirect_url)
      raw_cookies = headers["set-cookie"] || headers["Set-Cookie"]
      cookies = case raw_cookies
      when String then raw_cookies.split("\n")
      when Array then raw_cookies
      else []
      end

      self.class.build_token(cookies: cookies, redirect_url: redirect_url)
    end

    def redirect_to_native(callback_scheme, token: nil, error: false)
      query = error ? "error=true" : "token=#{CGI.escape(token)}"
      [302, {"location" => "#{callback_scheme}://auth/callback?#{query}"}, [""]]
    end

    def oauth_paths
      RubyNative.config&.dig(:auth, :oauth_paths) || []
    end
  end
end
