require "test_helper"
require "json"

class RubyNative::PluginManifestsTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  PLUGIN = File.join(ROOT, "plugin")
  DIRECTORY_PLUGIN = File.join(ROOT, "directory-plugin")
  SHARED_FILES = %w[skills/ruby-native/SKILL.md icon.png]

  def test_directory_plugin_copies_match_the_plugin
    SHARED_FILES.each do |path|
      assert FileUtils.identical?(File.join(PLUGIN, path), File.join(DIRECTORY_PLUGIN, path)),
        "directory-plugin/#{path} differs from plugin/#{path}. Run: cp plugin/#{path} directory-plugin/#{path}"
    end
  end

  # Anthropic's directory rejects a local MCP server and any symlink the plugin loads.
  def test_directory_plugin_has_no_local_server_or_symlinks
    manifest = JSON.parse(File.read(File.join(DIRECTORY_PLUGIN, ".claude-plugin/plugin.json")))

    assert_nil manifest["mcpServers"]
    assert_nil manifest["userConfig"]
    refute File.exist?(File.join(DIRECTORY_PLUGIN, ".mcp.json"))
    refute File.exist?(File.join(DIRECTORY_PLUGIN, "bin"))
    assert_empty Dir.glob("**/*", File::FNM_DOTMATCH, base: DIRECTORY_PLUGIN).select { |path| File.symlink?(File.join(DIRECTORY_PLUGIN, path)) }
  end

  def test_both_plugins_share_a_name_and_version
    manifests = [PLUGIN, DIRECTORY_PLUGIN].map { |dir| JSON.parse(File.read(File.join(dir, ".claude-plugin/plugin.json"))) }

    assert_equal ["ruby-native"], manifests.map { |manifest| manifest["name"] }.uniq
    assert_equal [RubyNative::VERSION], manifests.map { |manifest| manifest["version"] }.uniq
  end
end
