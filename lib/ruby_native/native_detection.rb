module RubyNative
  module NativeDetection
    extend ActiveSupport::Concern

    # Matches "Ruby Native iOS/5.2/35 iOS/26.5.2/23F79 RubyNative/0.12.5". The
    # build, OS, and OS build groups are optional: apps built before the UA
    # carried them send only "Ruby Native iOS/5.2" (or later "... iOS/26.5.2"
    # without the OS build), and the optional groups keep the OS capture from
    # swallowing the app version.
    SIGNATURE = %r{Ruby Native (?:iOS|Android)/([\d.]+)(?:/([\d.]+) (?:iOS|Android)/([\d.]+)(?:/([\w.]+))?)?}

    included do
      if respond_to?(:helper_method)
        helper_method :native_app?, :native_version, :native_platform,
          :native_app_version, :native_app_build, :native_os_version, :native_os_build,
          :native_secure_session_completion_url
      end
    end

    def native_app?
      request.user_agent.to_s.include?("Ruby Native")
    end

    def native_version
      match = request.user_agent.to_s.match(/RubyNative\/([\d.]+)/)
      NativeVersion.new(match ? match[1] : "0")
    end

    # Returns "ios" or "android" for native requests, nil for web browsers.
    # Used by view helpers to pick the right icon from `icons: { ios:, android: }`.
    def native_platform
      ua = request.user_agent.to_s
      return "ios" if ua.include?("Ruby Native iOS")
      return "android" if ua.include?("Ruby Native Android")
      nil
    end

    # The app's marketing version, like "5.2". Nil for web browsers.
    def native_app_version
      request.user_agent.to_s[SIGNATURE, 1]
    end

    # The app's build number (CFBundleVersion / versionCode), like "35". Nil for
    # web browsers and apps built before the User-Agent carried it.
    def native_app_build
      request.user_agent.to_s[SIGNATURE, 2]
    end

    # The device's OS version, like "26.5.2". Nil for web browsers and apps built
    # before the User-Agent carried it.
    def native_os_version
      request.user_agent.to_s[SIGNATURE, 3]
    end

    # The device's OS build, like "23F79" (iOS) or "UQ1A.240205.004" (Android).
    # Nil for web browsers and apps built before the User-Agent carried it.
    def native_os_build
      request.user_agent.to_s[SIGNATURE, 4]
    end

    SECURE_SESSION_COOKIE = "_ruby_native_callback_scheme".freeze

    # Where a provider like Plaid Hosted Link or Stripe Connect onboarding sends
    # the user when they finish. Pass it as the provider's completion URI, then
    # link to the provider with `data: { native_secure_session: true }`. The app
    # opens the link in a secure browser and, on completion, loads `return_to`
    # in the web view, still signed in.
    #
    #   completion_redirect_uri: native_secure_session_completion_url(return_to: bank_done_path)
    #
    # Returns nil outside the app (or in a build without secure sessions), so
    # fall back to a regular web URL there.
    def native_secure_session_completion_url(return_to:)
      path = return_to.to_s
      unless path.start_with?("/") && !path.start_with?("//")
        raise ArgumentError, "return_to must be a path on your site, like /bank/done"
      end

      scheme = request.cookies[SECURE_SESSION_COOKIE].to_s
      return unless scheme.match?(OAuthMiddleware::CALLBACK_SCHEME)

      "#{scheme}://secure-session?#{{ return_to: path }.to_query}"
    end
  end
end
