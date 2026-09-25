require "minitest/autorun"
require "json"
require "ruby_native/cli/status"

class StatusTest < Minitest::Test
  def test_report_reads_top_to_bottom
    report = RubyNative::CLI::Status.report(status)

    assert_match "Trailhead (app_1) · https://trailhead.app", report
    assert_match "Dashboard: https://rubynative.com/apps/1", report
    assert_match "iOS: Setup complete · build 12 (1.0.0) ready · not on the App Store", report
    assert_match "Android: Play developer account · no build yet · not on the Google Play", report
    assert_match "Subscription: Launch, active", report
    assert_match "Before submitting, 2 things need doing:", report
  end

  def test_report_says_who_clears_each_blocker_and_whether_we_can_see_it
    report = RubyNative::CLI::Status.report(status)

    assert_match "1. app_privacy (a person does this; Ruby Native cannot see it, so it is marked done on the dashboard)", report
    assert_match "   Apple publishes no API for the App Privacy questionnaire.", report
    assert_match "     1. Open the app and click App Privacy.", report
    assert_match "2. no_build (an agent can do this; Ruby Native sees it clear)", report
  end

  def test_report_says_when_nothing_blocks_a_build
    report = RubyNative::CLI::Status.report(status("next" => "build", "blocked_by" => []))

    assert_match "Nothing is in the way of a build. Run `bundle exec ruby_native deploy`.", report
  end

  def test_report_names_a_paused_subscription
    report = RubyNative::CLI::Status.report(status("subscription" => { "active" => false, "past_due" => true }))

    assert_match "Subscription: past due, builds paused", report
  end

  def test_report_survives_an_empty_answer
    assert_match "Nothing is in the way of a build.", RubyNative::CLI::Status.report({})
  end

  def test_run_without_a_linked_app_says_how_to_link_one
    original = RubyNative::CLI::Mcp::Platform.method(:app_id)
    RubyNative::CLI::Mcp::Platform.define_singleton_method(:app_id) { |*| nil }

    out, _err = capture_io do
      assert_raises(SystemExit) { RubyNative::CLI::Status.new([]).run }
    end
    assert_match "No app is linked to this project.", out
  ensure
    RubyNative::CLI::Mcp::Platform.define_singleton_method(:app_id, original)
  end

  private

  def status(overrides = {})
    {
      "public_id" => "app_1", "name" => "Trailhead", "url" => "https://trailhead.app",
      "dashboard_url" => "https://rubynative.com/apps/1",
      "subscription" => { "active" => true, "past_due" => false, "plan" => "Launch" },
      "ios" => { "setup" => "Setup complete", "live" => false,
                 "latest_build" => { "number" => 12, "version" => "1.0.0", "status" => "ready" } },
      "android" => { "setup" => "Play developer account", "latest_build" => nil, "live" => false },
      "next" => "submit",
      "blocked_by" => [
        { "id" => "app_privacy", "who" => "human", "verifiable" => false,
          "why" => "Apple publishes no API for the App Privacy questionnaire.",
          "url" => "https://appstoreconnect.apple.com/apps/1/distribution/privacy",
          "steps" => [ "Open the app and click App Privacy." ] },
        { "id" => "no_build", "who" => "agent", "verifiable" => true,
          "why" => "Nothing has been built yet.", "url" => "https://rubynative.com/apps/1/builds",
          "steps" => [ "Run `bundle exec ruby_native deploy`." ] }
      ]
    }.merge(overrides)
  end
end
