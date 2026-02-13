module RubyNative
  class ConfigController < ::ActionController::Base
    def show
      RubyNative.load_config if Rails.env.local?
      render json: RubyNative.config
    end
  end
end
