module RubyNative
  module NativeDetection
    extend ActiveSupport::Concern

    included do
      helper_method :native_app?, :native_version if respond_to?(:helper_method)
    end

    def native_app?
      request.user_agent.to_s.include?("Ruby Native")
    end

    def native_version
      match = request.user_agent.to_s.match(/RubyNative\/([\d.]+)/)
      NativeVersion.new(match ? match[1] : "0")
    end
  end
end
