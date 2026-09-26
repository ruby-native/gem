require "minitest/autorun"
require "json"
require "tmpdir"
require "ruby_native/cli/demo_account"
require "ruby_native/cli/icon"
require "ruby_native/cli/listing"
require "ruby_native/cli/permissions"
require "ruby_native/cli/screenshots"
require "ruby_native/cli/submit"
require "stringio"
require "ruby_native/cli/testers"

# The CLI verbs the MCP server wraps. Each is checked here at the seam the
# server calls, so a tool and a command cannot answer differently.
class CommandsTest < Minitest::Test
  Platform = RubyNative::CLI::Mcp::Platform

  # --- permissions ---

  def test_permissions_list_says_which_are_missing
    outcome = with_get(ok("permissions" => { "camera" => "To scan", "microphone" => nil, "photos" => nil })) do
      RubyNative::CLI::Permissions.list("app_1")
    end

    assert outcome.ok
    assert_match "camera      To scan", outcome.text
    assert_match "microphone  (not set, the app cannot ask)", outcome.text
  end

  def test_permissions_set_refuses_an_unknown_name_locally
    outcome = RubyNative::CLI::Permissions.set("app_1", "location" => "x")

    refute outcome.ok
    assert_match 'Unknown permission "location"', outcome.text
  end

  def test_permissions_set_reports_no_change
    outcome = with_patch(ok("permissions" => { "camera" => "Same" }, "changed" => [], "rebuild_required" => false)) do
      RubyNative::CLI::Permissions.set("app_1", "camera" => "Same")
    end

    assert_match "Nothing changed.", outcome.text
  end

  def test_a_validation_failure_lists_the_field_errors_the_headline_does_not_already_state
    refusal = Platform::Result.new(error: "Camera usage description cannot contain line breaks", status: 422,
      body: { "errors" => { "camera_usage_description" => [ "cannot contain line breaks" ], "photo_library_usage_description" => [ "is too long" ] } })
    outcome = with_patch(refusal) { RubyNative::CLI::Permissions.set("app_1", "camera" => "a\nb") }

    refute outcome.ok
    assert_equal 1, outcome.text.scan("cannot contain line breaks").size
    assert_match "  photo_library_usage_description is too long", outcome.text
  end

  # --- link ---

  def test_link_writes_the_only_app_on_the_account
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p("config")
        File.write("config/ruby_native.yml", "app:\n  mode: normal\n")
        outcome = with_get(ok([ { "public_id" => "app_1", "name" => "Trailhead", "url" => "https://trailhead.app" } ])) { RubyNative::CLI::Link.link }

        assert outcome.ok
        assert_match "Linked to Trailhead (app_1)", outcome.text
        assert_equal "app_1", Platform.app_id("config/ruby_native.yml")
      end
    end
  end

  def test_link_lists_the_apps_when_there_are_several_and_none_was_named
    apps = [ { "public_id" => "app_1", "name" => "Trailhead" }, { "public_id" => "app_2", "name" => "Shelf" } ]
    outcome = with_get(ok(apps)) { RubyNative::CLI::Link.link }

    refute outcome.ok
    assert_match "app_1  Trailhead", outcome.text
    assert_match "app_2  Shelf", outcome.text
    assert_equal apps, outcome.data["apps"]
  end

  def test_link_refuses_an_app_id_that_is_not_on_the_account
    outcome = with_get(ok([ { "public_id" => "app_1", "name" => "Trailhead" } ])) { RubyNative::CLI::Link.link("app_9") }

    refute outcome.ok
    assert_match 'No app "app_9" on this account', outcome.text
  end

  # --- testers ---

  def test_testers_list_shows_who_has_accepted
    outcome = with_get(ok("testers" => [ { "email" => "dev@example.com", "accepted" => true }, { "email" => "qa@example.com", "accepted" => false } ])) do
      RubyNative::CLI::Testers.list("app_1")
    end

    assert_match "dev@example.com  accepted", outcome.text
    assert_match "qa@example.com   invited, not accepted", outcome.text
  end

  def test_testers_list_points_at_add_when_empty
    outcome = with_get(ok("testers" => [])) { RubyNative::CLI::Testers.list("app_1") }

    assert_match "ruby_native testers add <email>", outcome.text
  end

  def test_testers_add_relays_the_server_message
    outcome = with_post(ok("result" => "added", "message" => "Apple is emailing qa@example.com a TestFlight invite.")) do
      RubyNative::CLI::Testers.add("app_1", "qa@example.com")
    end

    assert outcome.ok
    assert_equal "Apple is emailing qa@example.com a TestFlight invite.", outcome.text
  end

  def test_testers_add_relays_a_non_member_refusal
    refusal = Platform::Result.new(error: "stranger@example.com is not on the App Store Connect team.", status: 422, body: { "result" => "not_a_member" })
    outcome = with_post(refusal) { RubyNative::CLI::Testers.add("app_1", "stranger@example.com") }

    refute outcome.ok
    assert_match "not on the App Store Connect team", outcome.text
  end

  # --- icon ---

  def test_icon_set_uploads_the_file_as_a_png
    Dir.mktmpdir do |dir|
      path = File.join(dir, "icon.png")
      File.write(path, "png")
      sent = nil
      answer = ok("note" => "Ships with the next `ruby_native deploy`.")
      outcome = with_stub(Platform, :put_file, ->(_path, **options) { sent = options; answer }) do
        RubyNative::CLI::Icon.set("app_1", path)
      end

      assert outcome.ok
      assert_equal "icon", sent[:field]
      assert_equal "image/png", sent[:content_type]
      assert_match "Icon set from #{path}. Ships with the next `ruby_native deploy`.", outcome.text
    end
  end

  # --- screenshots ---

  def test_screenshots_setup_leaves_an_existing_key_alone
    posted = false
    empty = ok({})
    outcome = with_get(ok("key_configured" => true, "paths" => [ "/" ])) do
      with_stub(Platform, :post, ->(*) { posted = true; empty }) { RubyNative::CLI::Screenshots.setup("app_1") }
    end

    refute posted
    assert_match "already set. Pass --rotate-key", outcome.text
  end

  def test_screenshots_setup_asks_for_pages_when_there_are_none
    outcome = with_get(ok("key_configured" => true, "paths" => [])) { RubyNative::CLI::Screenshots.setup("app_1") }

    assert_match "--paths /,/inbox,/settings", outcome.text
  end

  def test_screenshots_capture_names_the_capture
    outcome = with_post(ok("capture" => { "id" => 7, "platform" => "ios" }, "note" => "The capture takes about five minutes.")) do
      RubyNative::CLI::Screenshots.capture("app_1")
    end

    assert_match "Capturing ios screenshots (capture 7). The capture takes about five minutes.", outcome.text
  end

  def test_screenshots_list_reads_top_to_bottom
    outcome = with_get(ok("key_configured" => true, "paths" => [ "/", "/inbox", "/settings" ], "dashboard_url" => "https://rubynative.com/apps/1/screenshots",
      "captures" => { "ios" => { "id" => 7, "status" => "success", "in_progress" => false, "screenshots" => 3, "upload_status" => "uploaded" }, "android" => nil })) do
      RubyNative::CLI::Screenshots.list("app_1")
    end

    assert_match "Key: set", outcome.text
    assert_match "Pages: /, /inbox, /settings", outcome.text
    assert_match "iOS: capture 7 success, 3 screenshots, uploaded", outcome.text
    assert_match "Android: no capture yet", outcome.text
    assert_match "Publish them to the stores from https://rubynative.com/apps/1/screenshots.", outcome.text
  end

  # --- listing ---

  def test_listing_pull_on_an_empty_listing_writes_a_template_push_accepts
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("config")
        outcome = with_get(ok("listing" => {})) { RubyNative::CLI::Listing.pull("app_1") }

        assert outcome.ok
        assert_match "name: # up to 30 characters", File.read("config/ruby_native_listing.yml")
        refute_kind_of RubyNative::CLI::Command::Outcome, RubyNative::CLI::Listing.read_file
      end
    end
  end

  def test_listing_pull_writes_the_file_in_the_documented_order
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("config")
        listing = { "name" => "Trailhead", "description" => "Hikes.\nOffline.", "keywords" => "hiking,trail", "subtitle" => nil, "primary_category" => "Lifestyle", "promotional_text" => "Now: offline maps" }
        outcome = with_get(ok("listing" => listing)) { RubyNative::CLI::Listing.pull("app_1") }

        assert outcome.ok
        written = File.read("config/ruby_native_listing.yml")
        assert_equal <<~YAML, written
          # App Store listing. `ruby_native listing push` saves it to Ruby Native;
          # publishing to App Store Connect is a separate step.

          name: Trailhead
          subtitle: # up to 30 characters
          primary_category: Lifestyle
          secondary_category:
          keywords: hiking,trail
          promotional_text: "Now: offline maps"
          privacy_policy_url:
          description: |-
            Hikes.
            Offline.
        YAML
        assert_equal listing.compact, YAML.safe_load(written).slice(*listing.keys).compact
      end
    end
  end

  def test_listing_push_interpolates_erb_and_reports_missing_file
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        outcome = RubyNative::CLI::Listing.push("app_1")
        refute outcome.ok
        assert_match "No config/ruby_native_listing.yml.", outcome.text

        Dir.mkdir("config")
        File.write("config/ruby_native_listing.yml", "name: <%= 'Trail' + 'head' %>\n")
        sent = nil
        answer = ok("changed" => [ "name" ], "missing" => [])
        with_patch_capture(->(json) { sent = json; answer }) { RubyNative::CLI::Listing.push("app_1") }
        assert_equal "Trailhead", sent[:listing]["name"]
      end
    end
  end

  def test_listing_publish_pushes_first_and_stops_when_the_push_fails
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("config")
        File.write("config/ruby_native_listing.yml", "name: #{"n" * 31}\n")
        posted = false
        empty = ok({})
        outcome = with_stub(Platform, :post, ->(*) { posted = true; empty }) { RubyNative::CLI::Listing.publish("app_1") }

        refute outcome.ok
        refute posted
      end
    end
  end

  def test_listing_publish_relays_the_server_note
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("config")
        File.write("config/ruby_native_listing.yml", "name: Trailhead\n")
        pushed = ok("changed" => [], "missing" => [])
        published = ok("note" => "The listing is on App Store Connect for version 1.0.")
        outcome = with_patch(pushed) { with_post(published) { RubyNative::CLI::Listing.publish("app_1") } }

        assert outcome.ok
        assert_equal "The listing is on App Store Connect for version 1.0.", outcome.text
      end
    end
  end

  def test_listing_publish_android_sends_the_platform
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        Dir.mkdir("config")
        File.write("config/ruby_native_listing.yml", "name: Trailhead\nsubtitle: Maps\n")
        posted = nil
        pushed = ok("changed" => [], "missing" => [])
        published = ok("note" => "The title and descriptions are on the Play Console listing (en-US).")
        outcome = with_patch(pushed) do
          with_stub(Platform, :post, ->(_path, json = nil) { posted = json; published }) { RubyNative::CLI::Listing.publish("app_1", platform: "android") }
        end

        assert_equal({ platform: "android" }, posted)
        assert_match "Play Console listing", outcome.text
      end
    end
  end

  def test_testers_android_asks_for_the_play_hand_off
    asked = nil
    refusal = Platform::Result.new(error: "Google Play keeps its internal tester list in Play Console.", status: 422,
      body: { "blocked_by" => [ { "id" => "play_testers", "who" => "human", "verifiable" => false, "why" => "Console only.", "url" => "https://play.google.com/console", "steps" => [ "Create email list." ] } ] })
    outcome = with_stub(Platform, :get, ->(path) { asked = path; refusal }) { RubyNative::CLI::Testers.list("app_1", platform: "android") }

    assert_equal "/api/v1/apps/app_1/testers?platform=android", asked
    refute outcome.ok
    assert_match "1. play_testers (a person does this; Ruby Native cannot see it", outcome.text
    assert_match "1. Create email list.", outcome.text
  end

  def test_withdraw_android_asks_the_platform_route
    asked = nil
    refusal = Platform::Result.new(error: "Google Play releases are managed in Play Console.", status: 409, body: {})
    outcome = with_stub(Platform, :request, ->(_klass, path, **) { asked = path; refusal }) { RubyNative::CLI::Submit.withdraw("app_1", platform: "android") }

    assert_equal "/api/v1/apps/app_1/submission?platform=android", asked
    assert_match "Play Console", outcome.text
  end

  # --- demo account ---

  def test_demo_account_set_sends_only_what_was_given
    sent = nil
    answer = ok("demo_account" => { "name" => "reviewer@example.com", "password_set" => true })
    outcome = with_patch_capture(->(json) { sent = json; answer }) do
      RubyNative::CLI::DemoAccount.set("app_1", name: "reviewer@example.com", password: "hunter2")
    end

    assert_equal({ demo_account: { name: "reviewer@example.com", required: true, password: "hunter2" } }, sent)
    assert_match "Demo account reviewer@example.com saved. It reaches App Store Connect when the listing is published.", outcome.text
  end

  # --- submit ---

  def test_submit_asks_before_sending_and_stops_on_anything_but_yes
    preview = ok("summary" => "Submit Trailhead 1.0 for review.", "confirmation_token" => "tok")
    posts = []
    with_stub(Platform, :app_id, ->(*) { "app_1" }) do
      with_stub(RubyNative::CLI::Credentials, :token, ->(*) { "t" }) do
        with_stub(Platform, :post, ->(_path, json = nil) { posts << json; preview }) do
          $stdin = StringIO.new("no\n")
          out, _err = capture_io { assert_raises(SystemExit) { RubyNative::CLI::Submit.new([]).run } }

          assert_match "Submit Trailhead 1.0 for review.", out
          assert_match "Not submitted.", out
          assert_equal [ nil ], posts
        ensure
          $stdin = STDIN
        end
      end
    end
  end

  def test_submit_with_yes_sends_the_token_from_the_preview
    preview = ok("summary" => "Submit Trailhead 1.0 for review.", "confirmation_token" => "tok")
    done = ok("note" => "Submitted for App Store review.")
    posts = []
    with_stub(Platform, :app_id, ->(*) { "app_1" }) do
      with_stub(RubyNative::CLI::Credentials, :token, ->(*) { "t" }) do
        with_stub(Platform, :post, ->(_path, json = nil) { posts << json; posts.size == 1 ? preview : done }) do
          out, _err = capture_io { RubyNative::CLI::Submit.new([ "--yes" ]).run }

          assert_match "Submitted for App Store review.", out
          assert_equal [ nil, { confirmation_token: "tok" } ], posts
        end
      end
    end
  end

  private

  def with_patch_capture(capture, &block) = with_stub(Platform, :patch, ->(_path, json) { capture.call(json) }, &block)

  def ok(value)
    Platform::Result.new(value: value, status: 200)
  end

  def with_get(result, &block) = with_stub(Platform, :get, ->(*) { result }, &block)
  def with_patch(result, &block) = with_stub(Platform, :patch, ->(*) { result }, &block)
  def with_post(result, &block) = with_stub(Platform, :post, ->(*) { result }, &block)

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
