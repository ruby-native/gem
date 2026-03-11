module RubyNative
  class ConfigController < ::ActionController::Base
    def show
      RubyNative.load_config if Rails.env.local?
      response.set_header("X-Ruby-Native-Version", RubyNative::VERSION)
      render json: RubyNative.config
    end
  end
end
