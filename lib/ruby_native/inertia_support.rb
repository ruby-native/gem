module RubyNative
  module InertiaSupport
    extend ActiveSupport::Concern

    included do
      unless respond_to?(:inertia_share)
        raise "RubyNative::InertiaSupport requires the inertia_rails gem. Add it to your Gemfile."
      end

      inertia_share do
        { nativeApp: native_app?, nativeForm: @native_form || false }
      end
    end
  end
end
