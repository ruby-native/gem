require "minitest/autorun"
require "fileutils"
require "net/http"
require "tmpdir"
require "ruby_native/cli/mcp/platform"

class PlatformTest < Minitest::Test
  Platform = RubyNative::CLI::Mcp::Platform

  # --- Responses ---

  def test_a_json_body_comes_back_parsed
    result = interpret(response(Net::HTTPOK, "200", %([{"public_id":"app_1"}])))

    assert result.ok?
    assert_equal [ { "public_id" => "app_1" } ], result.value
  end

  # builds/latest answers 204 for a platform that has never built.
  def test_an_empty_body_is_a_success_with_nothing_in_it
    result = interpret(Net::HTTPNoContent.new("1.1", "204", "No Content"))

    assert result.ok?
    assert_nil result.value
  end

  def test_a_success_that_is_not_json_is_reported_rather_than_parsed
    result = interpret(response(Net::HTTPOK, "200", "<html>WAF</html>"))

    refute result.ok?
    assert_match "not JSON", result.error
  end

  def test_a_rejected_token_says_how_to_replace_it
    result = interpret(Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized"))

    assert_match "ruby_native login", result.error
  end

  def test_a_404_is_marked_so_a_caller_can_tell_it_apart
    result = interpret(Net::HTTPNotFound.new("1.1", "404", "Not Found"))

    refute result.ok?
    assert result.not_found?
  end

  # The API says more in its body than the status code does.
  def test_an_api_error_message_is_carried_through
    result = interpret(response(Net::HTTPUnprocessableEntity, "422", %({"error":"Build limit reached."}))) 

    assert_match "Build limit reached.", result.error
  end

  def test_a_server_error_without_a_body_still_names_the_status
    result = interpret(Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error"))

    assert_match "500", result.error
  end

  # --- get ---

  def test_get_without_a_token_says_to_log_in
    with_stub(RubyNative::CLI::Credentials, :token, -> { nil }) do
      assert_equal Platform::NOT_LOGGED_IN, Platform.get("/api/v1/apps").error
    end
  end

  def test_get_sends_the_stored_token
    sent = nil

    with_stub(RubyNative::CLI::Credentials, :token, -> { "tok_123" }) do
      with_stub(Net::HTTP, :start, ->(*_args, **_options, &_block) { response(Net::HTTPOK, "200", "[]") }) do
        with_stub(Net::HTTP::Get, :new, ->(uri) { sent = Net::HTTP::Get.allocate.tap { |r| r.send(:initialize, uri) } }) do
          Platform.get("/api/v1/apps")
        end
      end
    end

    assert_equal "Token tok_123", sent["Authorization"]
  end

  # A server that cannot be reached is an answer, not a crash: the tools turn
  # it into something the model can say back.
  def test_a_transport_failure_comes_back_as_a_result
    with_stub(RubyNative::CLI::Credentials, :token, -> { "tok_123" }) do
      with_stub(Net::HTTP, :start, ->(*_args, **_options, &_block) { raise SocketError, "getaddrinfo failed" }) do
        result = Platform.get("/api/v1/apps")

        refute result.ok?
        assert_match "Could not reach", result.error
        assert_match "getaddrinfo failed", result.error
      end
    end
  end

  # --- app_id ---

  def test_app_id_comes_from_the_config_file
    in_app do
      write_config("ruby_native:\n  app_id: app_abc123\n")

      assert_equal "app_abc123", Platform.app_id
    end
  end

  def test_app_id_is_nil_when_the_project_has_never_deployed
    in_app do
      write_config("tabs: []\n")

      assert_nil Platform.app_id
    end
  end

  def test_app_id_is_nil_without_a_config_file
    in_app { assert_nil Platform.app_id }
  end

  # The file is rendered as ERB before Rails parses it, and a logo built from
  # image_url must not stop the CLI from finding the app it is linked to.
  def test_app_id_survives_erb_elsewhere_in_the_file
    in_app do
      write_config(<<~YAML)
        appearance:
          navbar:
            logo: "<%= image_url("logo.png") %>"
        ruby_native:
          app_id: app_abc123
      YAML

      assert_equal "app_abc123", Platform.app_id
    end
  end

  def test_a_config_that_does_not_parse_means_no_app_id_rather_than_a_crash
    in_app do
      write_config("tabs:\n  - title: Home\n   path: /\n")

      assert_nil Platform.app_id
    end
  end

  private

  def interpret(response)
    Platform.send(:interpret, response)
  end

  def response(klass, code, body)
    klass.new("1.1", code, "").tap do |response|
      response.instance_variable_set(:@body, body)
      response.instance_variable_set(:@read, true)
    end
  end

  def write_config(yaml)
    FileUtils.mkdir_p("config")
    File.write("config/ruby_native.yml", yaml)
  end

  def in_app(&block)
    Dir.mktmpdir { |dir| Dir.chdir(dir, &block) }
  end

  def with_stub(receiver, name, replacement)
    original = receiver.method(name)
    own = receiver.singleton_class.instance_methods(false).include?(name)
    receiver.singleton_class.send(:remove_method, name) if own
    receiver.define_singleton_method(name, &replacement)
    yield
  ensure
    receiver.singleton_class.send(:remove_method, name)
    receiver.define_singleton_method(name, original) if own
  end
end
