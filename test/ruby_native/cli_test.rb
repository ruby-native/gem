require "minitest/autorun"
require "ruby_native/cli"

class CliTest < Minitest::Test
  def test_unknown_commands_exit_1_and_name_the_command
    out, _err = capture_io do
      error = assert_raises(SystemExit) { RubyNative::CLI.start(["depoly"]) }
      assert_equal 1, error.status
    end
    assert_match(/Unknown command: depoly/, out)
    assert_match(/Usage: ruby_native/, out)
  end

  def test_no_command_prints_usage_without_erroring
    out, _err = capture_io { RubyNative::CLI.start([]) }
    assert_match(/Usage: ruby_native/, out)
  end

  def test_usage_lists_every_flag
    out, _err = capture_io { RubyNative::CLI.start([]) }
    %w[--if-needed --android --platform= --port --url].each do |flag|
      assert_match(/#{Regexp.escape(flag)}/, out, "usage should mention #{flag}")
    end
  end

  def test_usage_lists_the_mcp_server
    out, _err = capture_io { RubyNative::CLI.start([]) }

    assert_match(/^  mcp /, out)
  end

  # Customers should never see a raw backtrace; a one-line report with the
  # class and message is enough to file an issue with.
  def test_unexpected_errors_exit_1_with_the_class_and_message
    failing = Object.new
    def failing.run = raise SocketError, "getaddrinfo: nodename nor servname provided"

    # `new` here is inherited from Class, so removing the override restores it.
    RubyNative::CLI::Deploy.define_singleton_method(:new) { |_argv| failing }

    out, _err = capture_io do
      error = assert_raises(SystemExit) { RubyNative::CLI.start(["deploy"]) }
      assert_equal 1, error.status
    end
    assert_match(/SocketError/, out)
    assert_match(/getaddrinfo/, out)
    assert_match(/report it/, out)
  ensure
    RubyNative::CLI::Deploy.singleton_class.send(:remove_method, :new)
  end
end
