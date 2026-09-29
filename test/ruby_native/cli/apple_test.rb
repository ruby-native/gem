require "minitest/autorun"
require "tmpdir"
require "ruby_native/cli/apple"

class AppleTest < Minitest::Test
  Platform = RubyNative::CLI::Mcp::Platform

  def test_set_key_reads_the_file_once_and_reports_apple_s_verdict
    with_key_file do |path|
      patched = nil
      checking = ok("state" => "checking")
      passed = ok("state" => "passed")
      states = [ checking, passed ]
      outcome = stubbing(:patch, ->(_path, json) { patched = json; checking }) do
        stubbing(:get, ->(_path) { states.shift || passed }) do
          RubyNative::CLI::Apple.stub_const_sleep { RubyNative::CLI::Apple.set_key("app_1", path: path, key_id: "K", issuer_id: "I", team_id: "T") }
        end
      end

      assert outcome.ok
      assert_equal "K", patched[:asc_key_id]
      assert_equal "I", patched[:asc_issuer_id]
      assert_equal "T", patched[:team_id]
      assert_equal "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----", patched[:asc_key]
      assert_match "Key verified", outcome.text
    end
  end

  def test_set_key_hands_back_apple_s_rejection
    with_key_file do |path|
      checking = ok("state" => "checking")
      failed = ok("state" => "failed", "error" => "authentication failed")
      outcome = stubbing(:patch, ->(*) { checking }) do
        stubbing(:get, ->(_path) { failed }) do
          RubyNative::CLI::Apple.stub_const_sleep { RubyNative::CLI::Apple.set_key("app_1", path: path, key_id: "K", issuer_id: "I", team_id: "T") }
        end
      end

      refute outcome.ok
      assert_match "Apple rejected the key: authentication failed", outcome.text
    end
  end

  def test_set_key_gives_up_waiting_without_calling_it_a_failure
    with_key_file do |path|
      checking = ok("state" => "checking")
      outcome = stubbing(:patch, ->(*) { checking }) do
        stubbing(:get, ->(_path) { checking }) do
          RubyNative::CLI::Apple.stub_const_sleep { RubyNative::CLI::Apple.set_key("app_1", path: path, key_id: "K", issuer_id: "I", team_id: "T", wait: 0) }
        end
      end

      assert outcome.ok
      assert_match "Still checking", outcome.text
    end
  end

  def test_set_key_refuses_a_missing_file_before_any_request
    outcome = stubbing(:patch, ->(*) { flunk "nothing should be sent" }) do
      RubyNative::CLI::Apple.set_key("app_1", path: "/nope/AuthKey.p8", key_id: "K", issuer_id: "I", team_id: "T")
    end

    refute outcome.ok
    assert_match "No file at /nope/AuthKey.p8", outcome.text
  end

  def test_run_prints_usage_without_the_four_parts
    out, _err = capture_io do
      stubbing(:app_id, ->(*) { "app_1" }) do
        with_token do
          assert_raises(SystemExit) { RubyNative::CLI::Apple.new([ "key", "AuthKey.p8" ]).run }
        end
      end
    end

    assert_match "Usage: ruby_native apple key", out
  end

  private

  def with_key_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "AuthKey.p8")
      File.write(path, "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----\n")
      yield path
    end
  end

  def ok(value)
    Platform::Result.new(value: value, status: 200)
  end

  def stubbing(name, replacement, &block)
    original = Platform.method(name)
    own = Platform.singleton_class.instance_methods(false).include?(name)
    Platform.singleton_class.send(:remove_method, name) if own
    Platform.define_singleton_method(name, &replacement)
    yield
  ensure
    Platform.singleton_class.send(:remove_method, name)
    Platform.define_singleton_method(name, original) if own
  end

  def with_token
    original = RubyNative::CLI::Credentials.method(:token)
    RubyNative::CLI::Credentials.define_singleton_method(:token) { "t" }
    yield
  ensure
    RubyNative::CLI::Credentials.define_singleton_method(:token, original)
  end
end
