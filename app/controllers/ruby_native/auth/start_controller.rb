module RubyNative
  module Auth
    class StartController < ::ActionController::Base
      def show
        @provider = params[:provider]

        unless @provider.match?(/\A[a-z0-9_]+\z/)
          head :bad_request
          return
        end

        oauth_paths = RubyNative.config&.dig(:auth, :oauth_paths) || []
        @oauth_path = oauth_paths.find { |p| p.end_with?(@provider) } || "/auth/#{@provider}"
        @callback_scheme = params[:callback_scheme]
      end
    end
  end
end
