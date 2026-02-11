module RubyNative
  module NativeDetection
    extend ActiveSupport::Concern

    def native_app?
      request.user_agent.to_s.include?("Ruby Native")
    end
  end
end
