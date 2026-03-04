module RubyNative
  class NativeVersion < Gem::Version
    def <=>(other)
      other = self.class.new(other) if other.is_a?(String)
      super
    end
  end
end
