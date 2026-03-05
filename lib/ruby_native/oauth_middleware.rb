module RubyNative
  class OAuthMiddleware
    COOKIE_NAME = "_ruby_native_oauth"

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      # Restore cached session cookies from a native OAuth completion.
      # The session endpoint stores cookies in Rails.cache and redirects
      # here with a _rn_session token. We inject them into the request
      # so the Cookies/Session middleware picks them up naturally.
      if (restore_token = request.params["_rn_session"])
        restore_session_cookies!(env, restore_token)
      end

      on_oauth_path = oauth_path?(request)
      started_native_oauth = on_oauth_path && request.params["ruby_native"] == "1"
      callback_scheme = request.params["callback_scheme"] if started_native_oauth

      status, headers, body = @app.call(env)

      if on_oauth_path && redirect?(status)
        relax_cookie_samesite!(headers)
      end

      if started_native_oauth && callback_scheme.present? && redirect?(status)
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

      # Set any restored cookies that the app didn't write itself on the
      # response so WKWebView persists them for future requests.
      if (restore_cookies = env["ruby_native.restore_cookies"])
        set_missing_cookies!(headers, restore_cookies)
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

    def set_missing_cookies!(headers, restore_cookies)
      existing = headers["set-cookie"]
      existing_names = case existing
      when String then existing.split("\n").map { |c| c.split("=").first.strip }
      when Array then existing.map { |c| c.split("=").first.strip }
      else []
      end

      new_cookies = restore_cookies.reject { |c| existing_names.include?(c.split("=").first.strip) }
      return if new_cookies.empty?

      all = case existing
      when String then [existing, *new_cookies].join("\n")
      when Array then (existing + new_cookies).join("\n")
      else new_cookies.join("\n")
      end
      headers["set-cookie"] = all

      Rails.logger.info { "[RubyNative] Set #{new_cookies.size} additional cookies on response" }
    end

    def restore_session_cookies!(env, token)
      cached = Rails.cache.read("ruby_native:oauth_session:#{token}")
      return unless cached

      Rails.cache.delete("ruby_native:oauth_session:#{token}")

      # Parse Set-Cookie strings to extract name=value pairs and inject
      # them into the request so downstream middleware sees them.
      cookie_pairs = cached.map { |c| c.split(";").first.strip }
      existing = env["HTTP_COOKIE"] || ""
      env["HTTP_COOKIE"] = [existing, *cookie_pairs].reject(&:blank?).join("; ")

      # Store the raw Set-Cookie strings so we can set any that the app
      # doesn't write itself on the response. This ensures WKWebView
      # persists all cookies (e.g. the user_id cookie) for future requests.
      env["ruby_native.restore_cookies"] = cached

      Rails.logger.info { "[RubyNative] Restored #{cached.size} session cookies from cache" }
    end

    def oauth_path?(request)
      oauth_paths.any? { |p| request.path == p }
    end

    def set_cookie(headers, callback_scheme)
      signed = verifier.generate(callback_scheme)
      Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, {
        value: signed,
        path: "/",
        httponly: true,
        secure: true,
        same_site: :none,
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

    # Apple Sign In uses form_post (a cross-origin POST callback).
    # SameSite=Lax cookies are not sent on cross-origin POSTs, which
    # breaks OmniAuth's state verification. Relax existing cookies
    # to SameSite=None so the session cookie survives Apple's callback.
    def relax_cookie_samesite!(headers)
      raw = headers["set-cookie"]
      return unless raw

      cookies = raw.is_a?(Array) ? raw : raw.split("\n")
      headers["set-cookie"] = cookies.map { |cookie|
        next cookie unless cookie.match?(/SameSite=Lax/i)
        cookie.gsub(/SameSite=Lax/i, "SameSite=None").then { |c|
          c.include?("Secure") ? c : "#{c}; Secure"
        }
      }.join("\n")
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

      Rails.logger.info { "[RubyNative] Captured #{cookies.size} cookies for token (raw type: #{raw_cookies.class})" }

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
