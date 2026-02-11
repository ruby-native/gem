module RubyNative
  class ConfigController < ::ActionController::Base
    def show
      render json: RubyNative.config
    end
  end
end
