module RubyNative
  class Engine < ::Rails::Engine
    isolate_namespace RubyNative

    initializer "ruby_native.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include RubyNative::NativeDetection
        helper RubyNative::Helper
      end
    end

    initializer "ruby_native.assets" do |app|
      app.config.assets.paths << root.join("app/assets/stylesheets") if app.config.respond_to?(:assets)
    end

    initializer "ruby_native.config" do
      config.after_initialize do
        RubyNative.load_config
      end
    end

    initializer "ruby_native.routes" do |app|
      app.routes.prepend do
        mount RubyNative::Engine, at: "/native"
      end
    end
  end
end
