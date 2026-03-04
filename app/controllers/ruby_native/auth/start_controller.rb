module RubyNative
  module Auth
    class StartController < ::ActionController::Base
      def show
        @provider = params[:provider]

        unless @provider.match?(/\A[a-z0-9_]+\z/)
          head :bad_request
          return
        end

        @callback_scheme = params[:callback_scheme]
      end
    end
  end
end
