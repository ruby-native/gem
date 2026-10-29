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
    assert_match "call `preview_check`", text
    assert_match "call `app_create`", text
    refute_match "/apps/new", text, "the agent creates the app; the browser is only for the account"
  end

  def test_the_prompt_stops_after_pushing_the_listing_and_publishes_only_on_the_persons_word
    text = RubyNative::CLI::Mcp::Prompts::SHIP

    assert_match "save it with `listing_push`, then stop", text
    assert_match "listing publish` only after they say it reads", text
  end
end
