require "minitest/autorun"
require "tmpdir"
require "ruby_native/cli/credentials"

class CredentialsTest < Minitest::Test
  def setup
    @original_env = ENV["RUBY_NATIVE_TOKEN"]
    @tmpdir = Dir.mktmpdir
    @original_path = RubyNative::CLI::Credentials::PATH
    RubyNative::CLI::Credentials.send(:remove_const, :PATH)
    RubyNative::CLI::Credentials.const_set(:PATH, File.join(@tmpdir, "credentials"))
  end

  def teardown
    ENV["RUBY_NATIVE_TOKEN"] = @original_env
    FileUtils.rm_rf(@tmpdir)
    RubyNative::CLI::Credentials.send(:remove_const, :PATH)
    RubyNative::CLI::Credentials.const_set(:PATH, @original_path)
  end

  def test_token_returns_env_var_when_set
    ENV["RUBY_NATIVE_TOKEN"] = "env_token_123"

    assert_equal "env_token_123", RubyNative::CLI::Credentials.token
  end

  def test_token_falls_back_to_file
    ENV.delete("RUBY_NATIVE_TOKEN")
    RubyNative::CLI::Credentials.save("file_token_456")

    assert_equal "file_token_456", RubyNative::CLI::Credentials.token
  end

  def test_env_var_takes_priority_over_file
    ENV["RUBY_NATIVE_TOKEN"] = "env_token_123"
    RubyNative::CLI::Credentials.save("file_token_456")

    assert_equal "env_token_123", RubyNative::CLI::Credentials.token
  end

  def test_token_returns_nil_when_no_env_or_file
    ENV.delete("RUBY_NATIVE_TOKEN")

    assert_nil RubyNative::CLI::Credentials.token
  end
end
