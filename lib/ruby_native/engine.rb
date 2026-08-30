module RubyNative
  class Engine < ::Rails::Engine
    isolate_namespace RubyNative

    initializer "ruby_native.inflections", before: "ruby_native.helpers" do
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym "IAP"
      end
    end

    initializer "ruby_native.filter_params" do |app|
      app.config.filter_parameters += [:signedPayload, :ruby_native_screenshot_key]
    end

    initializer "ruby_native.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include RubyNative::NativeDetection
        helper RubyNative::Helper
      end
    end

    initializer "ruby_native.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/assets/stylesheets")
        app.config.assets.paths << root.join("app/javascript")
      end
    end

    initializer "ruby_native.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end

    initializer "ruby_native.oauth_middleware", before: :build_middleware_stack do |app|
      app.middleware.insert_before ActionDispatch::Cookies, RubyNative::OAuthMiddleware
    end

    initializer "ruby_native.tunnel_cookie_middleware", before: :build_middleware_stack do |app|
      if Rails.env.development?
        app.middleware.insert_before ActionDispatch::Cookies, RubyNative::TunnelCookieMiddleware
      end
    end

    initializer "ruby_native.routes" do |app|
      app.routes.prepend do
        get "/.well-known/apple-app-site-association", to: "ruby_native/aasa#show"
        get "/.well-known/assetlinks.json", to: "ruby_native/assetlinks#show"
        mount RubyNative::Engine, at: "/native"
      end
    end
  end
end
