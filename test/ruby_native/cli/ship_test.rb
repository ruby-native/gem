require "minitest/autorun"
require "ruby_native/cli/ship"

class ShipTest < Minitest::Test
  def test_prints_the_same_prompt_the_mcp_server_serves
    out, _err = capture_io { RubyNative::CLI::Ship.new.run }

    assert_equal RubyNative::CLI::Mcp::Prompts::SHIP + "\n", out
  end

  # The prompt is the journey: every section the dashboard's rail has, in the
  # same order, and it stops at the same walls.
  def test_the_prompt_walks_install_polish_account_and_stores_in_order
    text = RubyNative::CLI::Mcp::Prompts::SHIP
    sections = [ "## 1. Ruby Native is in the app", "## 2. The first native pass", "## 3. The account and the app", "## 4. The stores", "## Rules" ]

    assert_equal sections, sections.sort_by { |section| text.index(section) }
    assert_match "ruby_native:install", text
    assert_match "appearance.background_color", text
    assert_match "ruby_native login", text
    assert_match "`who: human`", text
    assert_match "Do not run preview yourself", text
  end
end
