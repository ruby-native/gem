require "minitest/autorun"
require "json"
require "tmpdir"
require "ruby_native/cli/mcp/install"

class McpInstallTest < Minitest::Test
  def test_writes_the_server_into_a_new_mcp_json
    in_project do
      out, _err = capture_io { RubyNative::CLI::Mcp::Install.new.run }

      config = JSON.parse(File.read(".mcp.json"))
      assert_equal({ "command" => "bundle", "args" => %w[exec ruby_native mcp] }, config.dig("mcpServers", "ruby-native"))
      assert_match "Added the ruby-native server to .mcp.json.", out
      assert_match "Then say: set up Ruby Native in this app", out
    end
  end

  def test_keeps_other_servers_and_keys
    in_project do
      File.write(".mcp.json", JSON.generate("mcpServers" => { "other" => { "command" => "x" } }, "note" => "keep"))

      capture_io { RubyNative::CLI::Mcp::Install.new.run }

      config = JSON.parse(File.read(".mcp.json"))
      assert_equal "keep", config["note"]
      assert_equal %w[other ruby-native], config["mcpServers"].keys.sort
    end
  end

  def test_leaves_a_file_that_already_has_the_entry_alone
    in_project do
      capture_io { RubyNative::CLI::Mcp::Install.new.run }
      before = File.read(".mcp.json")
      File.utime(Time.at(0), Time.at(0), ".mcp.json")

      out, _err = capture_io { RubyNative::CLI::Mcp::Install.new.run }

      assert_equal before, File.read(".mcp.json")
      assert_equal Time.at(0), File.mtime(".mcp.json")
      assert_match "already has the ruby-native server", out
    end
  end

  def test_refuses_to_touch_a_file_that_is_not_json
    in_project do
      File.write(".mcp.json", "{ not json")

      out, _err = capture_io do
        assert_raises(SystemExit) { RubyNative::CLI::Mcp::Install.new.run }
      end

      assert_equal "{ not json", File.read(".mcp.json")
      assert_match "not valid JSON", out
    end
  end

  private

  def in_project(&block)
    Dir.mktmpdir { |dir| Dir.chdir(dir, &block) }
  end
end
