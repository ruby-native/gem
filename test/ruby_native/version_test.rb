require "test_helper"

class RubyNative::VersionTest < Minitest::Test
  def test_version_is_defined
    refute_nil RubyNative::VERSION
  end

  def test_version_is_a_string
    assert_kind_of String, RubyNative::VERSION
  end
end
