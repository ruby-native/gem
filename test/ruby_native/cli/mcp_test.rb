require "minitest/autorun"
require "fileutils"
require "json"
require "stringio"
require "tmpdir"
require "ruby_native/cli/mcp"

class McpTest < Minitest::Test
  # --- Protocol ---

  def test_initialize_answers_with_the_version_the_client_asked_for
    result = request("initialize", { "protocolVersion" => "2024-11-05" })["result"]

    assert_equal "2024-11-05", result["protocolVersion"]
    assert_equal "ruby_native", result.dig("serverInfo", "name")
    assert_equal RubyNative::VERSION, result.dig("serverInfo", "version")
    assert result["capabilities"].key?("tools")
  end

  # The spec asks a server that cannot speak the requested version to answer
  # with one it can, rather than failing the handshake.
  def test_initialize_answers_an_unknown_version_with_the_newest_one
    result = request("initialize", { "protocolVersion" => "1999-01-01" })["result"]

    assert_equal RubyNative::CLI::Mcp::PROTOCOL_VERSION, result["protocolVersion"]
  end

  def test_a_notification_gets_no_reply
    assert_empty exchange(%({"jsonrpc":"2.0","method":"notifications/initialized"}))
  end

  def test_tools_list_names_every_tool_as_read_only
    tools = request("tools/list")["result"]["tools"]

    assert_equal %w[check_views lookup_signals validate_config], tools.map { |tool| tool["name"] }.sort
    tools.each do |tool|
      assert tool.dig("annotations", "readOnlyHint"), "#{tool["name"]} should be marked read-only"
      refute_empty tool["description"].to_s
      assert_equal "object", tool.dig("inputSchema", "type")
    end
  end

  def test_ping_answers_empty
    assert_empty request("ping")["result"]
  end

  def test_an_unknown_method_is_a_json_rpc_error
    error = request("tools/dance")["error"]

    assert_equal(-32601, error["code"])
    assert_match "tools/dance", error["message"]
  end

  def test_an_unknown_tool_names_the_way_to_find_the_real_ones
    error = exchange(%({"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"deploy"}})).first["error"]

    assert_equal(-32602, error["code"])
    assert_match "tools/list", error["message"]
  end

  def test_unparseable_input_is_answered_rather_than_crashing_the_server
    responses = exchange("this is not json", %({"jsonrpc":"2.0","id":7,"method":"ping"}))

    assert_equal(-32700, responses.first.dig("error", "code"))
    assert_nil responses.first["id"]
    assert_equal 7, responses.last["id"], "the server should keep serving after bad input"
  end

  def test_a_request_that_is_not_an_object_is_rejected
    assert_equal(-32600, exchange("[1, 2, 3]").first.dig("error", "code"))
  end

  def test_blank_lines_are_skipped
    assert_equal 1, exchange("", "   ", %({"jsonrpc":"2.0","id":1,"method":"ping"})).size
  end

  # stdout carries the protocol and nothing else. Library code underneath is
  # free to `puts` -- Check does on the paths this does not take -- so a stray
  # line must not land between two JSON messages and desync the client.
  def test_library_output_on_stdout_never_reaches_the_protocol_stream
    with_noisy_check do
      in_app do
        write_template("<div data-native-tabs hidden></div>")

        responses = exchange(tool_call(1, "check_views"))

        assert_equal 1, responses.size
        assert_equal 1, responses.first["id"]
      end
    end
  end

  # --- check_views ---

  def test_check_views_reports_a_clean_app
    result = in_app do
      write_template("<div data-native-tabs hidden></div>")
      call("check_views")
    end

    refute result["isError"]
    assert_match "No problems found.", text(result)
    assert_equal 1, result.dig("structuredContent", "checked")
    assert_empty result.dig("structuredContent", "offenses")
  end

  def test_check_views_reports_an_unknown_signal_with_a_place_to_look
    result = in_app do
      write_template("<div data-native-tab hidden></div>")
      call("check_views")
    end

    offense = result.dig("structuredContent", "offenses").first

    assert_equal "app/views/pages/show.html.erb", offense["file"]
    assert_equal 1, offense["line"]
    assert_equal "error", offense["severity"]
    assert_match "Did you mean `data-native-tabs`?", offense["message"]
    assert_equal 1, result.dig("structuredContent", "errors")
  end

  def test_check_views_says_so_when_there_is_nothing_to_check
    result = in_app { call("check_views") }

    assert_match "No .html.erb templates found in app/views.", text(result)
    assert_equal 0, result.dig("structuredContent", "checked")
  end

  def test_check_views_scans_the_paths_it_is_given
    result = in_app do
      FileUtils.mkdir_p("app/components")
      File.write("app/components/card.html.erb", "<div data-native-tab hidden></div>")

      call("check_views", "paths" => ["app/components"])
    end

    assert_equal ["app/components"], result.dig("structuredContent", "paths")
    assert_equal 1, result.dig("structuredContent", "errors")
  end

  def test_check_views_rejects_paths_that_are_not_strings
    error = exchange(tool_call(1, "check_views", "paths" => [3])).first["error"]

    assert_equal(-32602, error["code"])
    assert_match "list of strings", error["message"]
  end

  # --- lookup_signals ---

  def test_lookup_signals_lists_the_whole_vocabulary
    result = call("lookup_signals")

    assert_equal RubyNative::Signals.names.size, result.dig("structuredContent", "count")
    assert_match "data-native-tabs", text(result)
  end

  def test_lookup_signals_takes_a_bare_name
    result = call("lookup_signals", "name" => "fab")
    structured = result["structuredContent"]

    assert_equal "data-native-fab", structured["name"]
    assert structured["known"]
    assert_equal "native_fab_tag", structured["helper"]
  end

  def test_lookup_signals_suggests_a_signal_for_a_near_miss
    structured = call("lookup_signals", "name" => "data-native-tab")["structuredContent"]

    refute structured["known"]
    assert_equal "data-native-tabs", structured["suggestion"]
  end

  def test_lookup_signals_offers_no_guess_for_something_unrelated
    structured = call("lookup_signals", "name" => "wombat")["structuredContent"]

    refute structured["known"]
    assert_nil structured["suggestion"]
  end

  # The whole point of the version column: a signal the installed gem has never
  # heard of is inert on device, and nothing says so at runtime.
  def test_lookup_signals_flags_a_signal_this_gem_is_too_old_for
    with_version("0.1.0") do
      structured = call("lookup_signals", "name" => "data-native-fab")["structuredContent"]

      refute structured["supported"]
      assert_equal "0.1.0", structured["gem_version"]
    end
  end

  # --- validate_config ---

  def test_validate_config_reports_a_clean_file
    result = in_app do
      write_config(<<~YAML)
        tabs:
          - title: Home
            path: /
            icon: house
      YAML

      call("validate_config")
    end

    refute result["isError"]
    assert_match "No problems found.", text(result)
  end

  def test_validate_config_points_at_the_tab_that_is_missing_an_icon
    result = in_app do
      write_config(<<~YAML)
        tabs:
          - title: Home
            path: /
            icon: house
          - title: Profile
            path: /profile
      YAML

      call("validate_config")
    end

    offense = result.dig("structuredContent", "offenses").last

    assert_equal "tabs[1].icon", offense["key"]
    assert_equal 5, offense["line"]
    assert_equal "error", offense["severity"]
  end

  def test_validate_config_says_where_the_file_should_be
    result = in_app { call("validate_config") }

    assert_match "config/ruby_native.yml does not exist", text(result)
    assert_match "rails generate ruby_native:install", text(result)
  end

  def test_validate_config_reads_the_path_it_is_given
    result = in_app do
      FileUtils.mkdir_p("config")
      File.write("config/other.yml", "tabs: []\n")

      call("validate_config", "path" => "config/other.yml")
    end

    assert_equal "config/other.yml", result.dig("structuredContent", "path")
    assert_match "No problems found.", text(result)
  end

  private

  def call(name, arguments = {})
    exchange(tool_call(1, name, arguments)).first["result"]
  end

  def tool_call(id, name, arguments = {})
    JSON.generate(jsonrpc: "2.0", id: id, method: "tools/call", params: { name: name, arguments: arguments })
  end

  def request(method, params = nil)
    message = { jsonrpc: "2.0", id: 1, method: method }
    message[:params] = params if params

    exchange(JSON.generate(message)).first
  end

  def exchange(*lines)
    output = StringIO.new

    capture_io do
      RubyNative::CLI::Mcp.new([], input: StringIO.new(lines.join("\n") + "\n"), output: output).run
    end

    output.string.lines.map { |line| JSON.parse(line) }
  end

  def text(result)
    result["content"].first["text"]
  end

  def write_template(erb)
    FileUtils.mkdir_p("app/views/pages")
    File.write("app/views/pages/show.html.erb", erb)
  end

  def write_config(yaml)
    FileUtils.mkdir_p("config")
    File.write("config/ruby_native.yml", yaml)
  end

  def in_app(&block)
    Dir.mktmpdir { |dir| Dir.chdir(dir, &block) }
  end

  def with_noisy_check
    klass = RubyNative::CLI::Check
    original = klass.method(:signal_offenses)
    klass.singleton_class.send(:remove_method, :signal_offenses)
    klass.define_singleton_method(:signal_offenses) do |**|
      puts "a library wrote to stdout"
      []
    end

    yield
  ensure
    klass.singleton_class.send(:remove_method, :signal_offenses)
    klass.define_singleton_method(:signal_offenses, original)
  end

  def with_version(version)
    original = RubyNative::VERSION
    RubyNative.send(:remove_const, :VERSION)
    RubyNative.const_set(:VERSION, version)
    yield
  ensure
    RubyNative.send(:remove_const, :VERSION)
    RubyNative.const_set(:VERSION, original)
  end
end
