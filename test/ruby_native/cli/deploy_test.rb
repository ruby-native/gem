require "minitest/autorun"
require "tmpdir"
require "ruby_native/cli/deploy"

class DeployTest < Minitest::Test
  def setup
    @original_env = ENV["RUBY_NATIVE_TOKEN"]
    ENV.delete("RUBY_NATIVE_TOKEN")
  end

  def teardown
    ENV["RUBY_NATIVE_TOKEN"] = @original_env
  end

  def test_skip_build_when_gem_version_matches
    deploy = build_deploy(gem_version: RubyNative::VERSION)
    assert deploy.send(:skip_build?, "app_123")
  end

  def test_no_skip_when_gem_version_is_older
    deploy = build_deploy(gem_version: "0.1.0")
    refute deploy.send(:skip_build?, "app_123")
  end

  def test_no_skip_when_no_prior_build
    deploy = build_deploy(latest_build: nil)
    refute deploy.send(:skip_build?, "app_123")
  end

  def test_no_skip_when_gem_version_is_nil
    deploy = build_deploy(gem_version: nil)
    refute deploy.send(:skip_build?, "app_123")
  end

  def test_skip_when_latest_version_is_ahead
    deploy = build_deploy(gem_version: "99.0.0")
    assert deploy.send(:skip_build?, "app_123")
  end

  def test_no_skip_on_malformed_version
    deploy = build_deploy(gem_version: "not.a.version")
    refute deploy.send(:skip_build?, "app_123")
  end

  def test_latest_build_request_is_platform_scoped
    deploy = RubyNative::CLI::Deploy.new(["--android"])
    captured = nil
    deploy.define_singleton_method(:make_request) do |uri, _req|
      captured = uri
      Net::HTTPNoContent.new("1.1", "204", "No Content")
    end
    deploy.send(:fetch_latest_build, "app_123")
    assert_includes captured.to_s, "platform=android"
  end

  # --- Every configured platform ---

  def test_deploy_builds_every_platform_by_default
    assert_equal "all", RubyNative::CLI::Deploy.new([]).send(:requested_platform)
  end

  def test_ios_flag_narrows_to_ios
    assert_equal "ios", RubyNative::CLI::Deploy.new(["--ios"]).send(:requested_platform)
  end

  def test_skip_when_every_deployable_platform_is_current
    deploy = all_platform_deploy(
      "ios" => { "deployable" => true, "gem_version" => "99.0.0" },
      "android" => { "deployable" => true, "gem_version" => "99.0.0" }
    )

    assert deploy.send(:skip_build?, "app_123")
  end

  def test_no_skip_when_one_platform_is_behind
    deploy = all_platform_deploy(
      "ios" => { "deployable" => true, "gem_version" => "99.0.0" },
      "android" => { "deployable" => true, "gem_version" => "0.1.0" }
    )

    refute deploy.send(:skip_build?, "app_123")
  end

  # An iOS-only app would otherwise rebuild on every CI run, because Android
  # reports no build and "never built" would read as "needs building".
  def test_a_platform_that_is_not_set_up_does_not_block_skipping
    deploy = all_platform_deploy(
      "ios" => { "deployable" => true, "gem_version" => "99.0.0" },
      "android" => { "deployable" => false, "gem_version" => nil }
    )

    assert deploy.send(:skip_build?, "app_123")
  end

  # The opposite case, and the reason `deployable` is reported separately: a
  # track that is set up but has never built has to build.
  def test_a_configured_platform_with_no_build_is_not_skipped
    deploy = all_platform_deploy(
      "ios" => { "deployable" => true, "gem_version" => "99.0.0" },
      "android" => { "deployable" => true, "gem_version" => nil }
    )

    refute deploy.send(:skip_build?, "app_123")
  end

  def test_no_skip_when_no_platform_can_deploy
    deploy = all_platform_deploy(
      "ios" => { "deployable" => false, "gem_version" => nil },
      "android" => { "deployable" => false, "gem_version" => nil }
    )

    refute deploy.send(:skip_build?, "app_123")
  end

  # --- Platform validation ---

  def test_platform_flag_accepts_android
    deploy = RubyNative::CLI::Deploy.new(["--platform=android"])
    assert deploy.send(:android?)
  end

  def test_platform_flag_accepts_all
    assert_equal "all", RubyNative::CLI::Deploy.new(["--platform=all"]).send(:requested_platform)
  end

  def test_platform_typos_error_instead_of_silently_building_ios
    out, _err = capture_io do
      error = assert_raises(SystemExit) { RubyNative::CLI::Deploy.new(["--platform=adnroid"]) }
      assert_equal 1, error.status
    end
    assert_match(/Unknown platform "adnroid"/, out)
    assert_match(/--platform=ios, --platform=android, or --platform=all/, out)
  end

  # --- Token handling ---

  # `deploy --if-needed` is the command the docs put in CI, so an expired token
  # must produce the same advice as a regular deploy, not a raw exception.
  def test_if_needed_run_rescues_an_expired_token
    deploy = stubbed_deploy(["--if-needed"])
    deploy.define_singleton_method(:resolve_app_id!) { "app_123" }
    deploy.define_singleton_method(:fetch_latest_build) { |_app_id| raise RubyNative::CLI::Deploy::TokenExpiredError }

    out, _err = capture_io do
      error = assert_raises(SystemExit) { deploy.run }
      assert_equal 1, error.status
    end
    assert_match(/Token expired\. Run `ruby_native login` again\./, out)
  end

  def test_run_rescues_an_expired_token_from_app_linking
    deploy = stubbed_deploy([])
    deploy.define_singleton_method(:resolve_app_id!) { raise RubyNative::CLI::Deploy::TokenExpiredError }

    out, _err = capture_io do
      assert_raises(SystemExit) { deploy.run }
    end
    assert_match(/Token expired/, out)
  end

  # RUBY_NATIVE_TOKEN overrides the login file, so telling someone to re-login
  # while it is set sends them in circles.
  def test_expired_token_message_names_the_env_var_when_set
    ENV["RUBY_NATIVE_TOKEN"] = "stale-token"
    deploy = stubbed_deploy([])
    deploy.define_singleton_method(:resolve_app_id!) { raise RubyNative::CLI::Deploy::TokenExpiredError }

    out, _err = capture_io do
      assert_raises(SystemExit) { deploy.run }
    end
    assert_match(/RUBY_NATIVE_TOKEN/, out)
    refute_match(/Token expired\. Run `ruby_native login` again\./, out)
  end

  def test_blank_env_token_is_called_out_when_not_authenticated
    ENV["RUBY_NATIVE_TOKEN"] = ""
    deploy = RubyNative::CLI::Deploy.new([])

    out, _err = capture_io do
      assert_raises(SystemExit) do
        with_singleton_stub(RubyNative::CLI::Credentials, :file_token, -> { nil }) do
          deploy.send(:ensure_authenticated!)
        end
      end
    end
    assert_match(/RUBY_NATIVE_TOKEN is set but empty/, out)
    assert_match(/CI secret/, out)
  end

  # --- Network errors ---

  def test_make_request_wraps_network_errors_naming_the_host
    deploy = RubyNative::CLI::Deploy.new([])
    raising_http = Object.new
    def raising_http.use_ssl=(_value); end
    def raising_http.open_timeout=(_value); end
    def raising_http.read_timeout=(_value); end
    def raising_http.request(_req) = raise Errno::ECONNREFUSED

    uri = URI("https://rubynative.com/api/v1/apps")
    error = with_singleton_stub(Net::HTTP, :new, ->(*_args) { raising_http }) do
      assert_raises(RubyNative::CLI::Deploy::ConnectionError) do
        deploy.send(:make_request, uri, Net::HTTP::Get.new(uri))
      end
    end
    assert_match(/rubynative\.com/, error.message)
    assert_match(/ECONNREFUSED/, error.message)
  end

  def test_run_turns_connection_errors_into_a_friendly_exit
    deploy = stubbed_deploy([])
    deploy.define_singleton_method(:resolve_app_id!) do
      raise RubyNative::CLI::Deploy::ConnectionError, "Could not connect to rubynative.com (SocketError: boom)."
    end

    out, _err = capture_io do
      error = assert_raises(SystemExit) { deploy.run }
      assert_equal 1, error.status
    end
    assert_match(/Could not connect to rubynative\.com/, out)
    assert_match(/Check your internet connection/, out)
  end

  # --- Polling ---

  def test_poll_rides_out_transient_network_failures
    deploy = poll_deploy
    results = [
      -> { raise RubyNative::CLI::Deploy::ConnectionError, "Could not connect to rubynative.com (Net::ReadTimeout)." },
      -> { raise RubyNative::CLI::Deploy::ConnectionError, "Could not connect to rubynative.com (Net::ReadTimeout)." },
      -> { [:ok, { "status" => "success", "version" => "1.0", "number" => 7 }] }
    ]
    deploy.define_singleton_method(:fetch_build_status) { |_app_id, _build_id| results.shift.call }

    out, _err = capture_io do
      deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued" })
    end
    assert_match(/Build succeeded!/, out)
    assert_empty results
  end

  def test_poll_gives_up_after_three_consecutive_network_failures
    deploy = poll_deploy
    deploy.define_singleton_method(:fetch_build_status) do |_app_id, _build_id|
      raise RubyNative::CLI::Deploy::ConnectionError, "Could not connect to rubynative.com (Net::ReadTimeout)."
    end

    out, _err = capture_io do
      error = assert_raises(SystemExit) { deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued" }) }
      assert_equal 1, error.status
    end
    assert_match(/Could not connect to rubynative\.com/, out)
    assert_match(/still running server-side/, out)
    assert_match(/dashboard/, out)
  end

  # --- Polling every build a deploy started ---

  # The whole reason this exists: iOS succeeding used to exit 0 while Android
  # failed unnoticed, leaving CI green over a broken release.
  def test_poll_fails_when_any_platform_fails
    deploy = poll_deploy
    deploy.define_singleton_method(:fetch_build_status) do |_app_id, build_id|
      if build_id == 1
        [:ok, { "status" => "success", "version" => "1.0", "number" => 7, "platform" => "ios" }]
      else
        [:ok, { "status" => "failure", "error_message" => "Gradle exploded", "platform" => "android" }]
      end
    end

    out, _err = capture_io do
      error = assert_raises(SystemExit) { poll_both(deploy) }
      assert_equal 1, error.status
    end

    assert_match(/iOS: Build succeeded!/, out)
    assert_match(/Android: Build failed\./, out)
    assert_match(/Gradle exploded/, out)
  end

  def test_poll_succeeds_when_every_platform_succeeds
    deploy = poll_deploy
    deploy.define_singleton_method(:fetch_build_status) do |_app_id, build_id|
      platform = build_id == 1 ? "ios" : "android"
      [:ok, { "status" => "success", "version" => "1.0", "number" => 7, "platform" => platform }]
    end

    out, _err = capture_io { poll_both(deploy) }

    assert_match(/iOS: Build succeeded!/, out)
    assert_match(/Android: Build succeeded!/, out)
  end

  def test_poll_labels_platforms_only_when_there_is_more_than_one
    deploy = poll_deploy
    deploy.define_singleton_method(:fetch_build_status) do |_app_id, _build_id|
      [:ok, { "status" => "success", "version" => "1.0", "number" => 7, "platform" => "ios" }]
    end

    out, _err = capture_io do
      deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued", "platform" => "ios" })
    end

    assert_match(/Build succeeded!/, out)
    refute_match(/iOS:/, out)
  end

  # One platform answering is enough to keep the deploy alive, so a blip on the
  # other does not spend the whole failure budget.
  def test_poll_survives_one_platform_being_unreachable
    deploy = poll_deploy
    android_attempts = 0
    deploy.define_singleton_method(:fetch_build_status) do |_app_id, build_id|
      if build_id == 1
        [:ok, { "status" => "success", "version" => "1.0", "number" => 7, "platform" => "ios" }]
      else
        android_attempts += 1
        raise RubyNative::CLI::Deploy::ConnectionError, "Could not connect." if android_attempts < 4

        [:ok, { "status" => "success", "version" => "1.0", "number" => 8, "platform" => "android" }]
      end
    end

    out, _err = capture_io { poll_both(deploy) }

    assert_match(/Android: Build succeeded!/, out)
  end

  def test_poll_stops_early_on_a_persistent_404
    deploy = poll_deploy
    deploy.define_singleton_method(:fetch_build_status) { |_app_id, _build_id| [:not_found, nil] }

    out, _err = capture_io do
      error = assert_raises(SystemExit) { deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued" }) }
      assert_equal 1, error.status
    end
    assert_match(/no longer find this build \(404\)/, out)
    assert_match(/deleted or archived/, out)
  end

  def test_poll_reports_server_errors_once_and_keeps_going
    deploy = poll_deploy
    results = [
      -> { [:error, "HTTP 502"] },
      -> { [:error, "HTTP 502"] },
      -> { [:ok, { "status" => "success", "version" => "1.0", "number" => 7 }] }
    ]
    deploy.define_singleton_method(:fetch_build_status) { |_app_id, _build_id| results.shift.call }

    out, _err = capture_io do
      deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued" })
    end
    assert_equal 1, out.scan(/HTTP 502/).count
    assert_match(/Still trying/, out)
    assert_match(/Build succeeded!/, out)
  end

  def test_fetch_build_status_classifies_responses
    responses = {
      http_response(Net::HTTPOK, "200", body: '{"status":"building"}') => [:ok, { "status" => "building" }],
      http_response(Net::HTTPNotFound, "404") => [:not_found, nil],
      http_response(Net::HTTPBadGateway, "502") => [:error, "HTTP 502"],
      http_response(Net::HTTPOK, "200", body: "<html>WAF</html>") => [:error, "an unreadable response (HTTP 200)"]
    }

    responses.each do |response, expected|
      deploy = trigger_deploy(response)
      assert_equal expected, deploy.send(:fetch_build_status, "app_123", 1)
    end
  end

  def test_fetch_build_status_aborts_on_401
    deploy = RubyNative::CLI::Deploy.new([])
    response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
    deploy.define_singleton_method(:make_request) { |_uri, _req| response }

    out, _err = capture_io do
      assert_raises(SystemExit) { deploy.send(:fetch_build_status, "app_123", 1) }
    end
    assert_match(/Token expired/, out)
  end

  # --- Server notices ---

  def test_trigger_prints_a_server_notice
    body = '{"id":1,"number":7,"version":"1.0","status":"queued","notice":"Payment failed, this release goes to TestFlight only."}'
    deploy = trigger_deploy(http_response(Net::HTTPCreated, "201", body: body))

    out, _err = capture_io { deploy.send(:trigger_build, "app_123") }
    assert_match(/Notice: Payment failed, this release goes to TestFlight only\./, out)
  end

  def test_trigger_prints_no_notice_line_without_one
    body = '{"id":1,"number":7,"version":"1.0","status":"queued"}'
    deploy = trigger_deploy(http_response(Net::HTTPCreated, "201", body: body))

    out, _err = capture_io { deploy.send(:trigger_build, "app_123") }
    refute_match(/Notice:/, out)
  end

  def test_poll_prints_a_repeated_notice_once
    deploy = poll_deploy
    notice = "Payment failed, this release goes to TestFlight only."
    results = [
      -> { [:ok, { "status" => "building", "notice" => notice }] },
      -> { [:ok, { "status" => "building", "notice" => notice }] },
      -> { [:ok, { "status" => "success", "version" => "1.0", "number" => 7, "notice" => notice }] }
    ]
    deploy.define_singleton_method(:fetch_build_status) { |_app_id, _build_id| results.shift.call }

    out, _err = capture_io do
      deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued" })
    end
    assert_equal 1, out.scan(/Notice:/).count
    assert_match(/Notice: #{Regexp.escape(notice)}/, out)
    assert_match(/Build succeeded!/, out)
  end

  # A future server could scope notices per status; a changed string prints again.
  def test_poll_prints_a_changed_notice_again
    deploy = poll_deploy
    results = [
      -> { [:ok, { "status" => "building", "notice" => "First heads up." }] },
      -> { [:ok, { "status" => "success", "version" => "1.0", "number" => 7, "notice" => "Second heads up." }] }
    ]
    deploy.define_singleton_method(:fetch_build_status) { |_app_id, _build_id| results.shift.call }

    out, _err = capture_io do
      deploy.send(:poll_build_status, "app_123", { "id" => 1, "status" => "queued" })
    end
    assert_match(/Notice: First heads up\./, out)
    assert_match(/Notice: Second heads up\./, out)
  end

  def test_notice_ignores_non_string_and_blank_values
    deploy = RubyNative::CLI::Deploy.new([])

    out, _err = capture_io do
      deploy.send(:print_notice, { "notice" => { "unexpected" => "shape" } })
      deploy.send(:print_notice, { "notice" => " " })
      deploy.send(:print_notice, {})
    end
    assert_empty out
  end

  # --- Trigger responses ---

  def test_trigger_404_suggests_checking_the_dashboard_before_unlinking
    deploy = trigger_deploy(http_response(Net::HTTPNotFound, "404"))

    out, _err = capture_io do
      assert_raises(SystemExit) { deploy.send(:trigger_build, "app_123") }
    end
    assert_match(/may have been archived/, out)
    assert_match(/Check your apps first/, out)
    assert_match(/If you meant to link a different app/, out)
  end

  def test_trigger_with_an_unreadable_201_body_still_reports_the_queued_build
    deploy = trigger_deploy(http_response(Net::HTTPCreated, "201", body: "<html>proxy</html>"))

    out, _err = capture_io do
      error = assert_raises(SystemExit) { deploy.send(:trigger_build, "app_123") }
      assert_equal 0, error.status
    end
    assert_match(/queued/, out)
    assert_match(/dashboard/, out)
  end

  def test_trigger_conflict_with_an_html_body_reports_a_fallback_message
    deploy = trigger_deploy(http_response(Net::HTTPConflict, "409", body: "<html>WAF</html>"))

    out, _err = capture_io do
      assert_raises(SystemExit) { deploy.send(:trigger_build, "app_123") }
    end
    assert_match(/already in progress/, out)
  end

  # --- JSON guards ---

  def test_fetch_latest_build_tolerates_a_non_json_body
    deploy = RubyNative::CLI::Deploy.new([])
    response = http_response(Net::HTTPOK, "200", body: "<html>challenge page</html>")
    deploy.define_singleton_method(:make_request) { |_uri, _req| response }

    out, _err = capture_io do
      assert_nil deploy.send(:fetch_latest_build, "app_123")
    end
    assert_match(/HTTP 200/, out)
    assert_match(/not JSON/, out)
  end

  def test_fetch_apps_tolerates_a_non_json_body
    deploy = RubyNative::CLI::Deploy.new([])
    response = http_response(Net::HTTPOK, "200", body: "<html>challenge page</html>")
    deploy.define_singleton_method(:make_request) { |_uri, _req| response }

    out, _err = capture_io do
      assert_nil deploy.send(:fetch_apps)
    end
    assert_match(/not JSON/, out)
  end

  # --- Config reading ---

  def test_cli_renders_erb_in_the_config_like_rails_does
    with_config_file(<<~YAML) do |deploy|
      app:
        name: App
      appearance:
        navbar:
          logo: '<%= image_url("logo.png") %>'
      ruby_native:
        app_id: app_123
    YAML
      deploy.send(:load_config!)
      config = deploy.instance_variable_get(:@config)
      assert_equal "app_123", config.dig(:ruby_native, :app_id)
      assert_equal "", config.dig(:appearance, :navbar, :logo)
    end
  end

  def test_cli_survives_erb_control_flow_tags
    with_config_file(<<~YAML) do |deploy|
      app:
        name: App
      <% if false %>
      tabs: []
      <% end %>
      ruby_native:
        app_id: app_123
    YAML
      deploy.send(:load_config!)
      assert_equal "app_123", deploy.instance_variable_get(:@config).dig(:ruby_native, :app_id)
    end
  end

  def test_yaml_syntax_errors_name_the_file_instead_of_a_backtrace
    with_config_file("app: [\n") do |deploy|
      out, _err = capture_io do
        error = assert_raises(SystemExit) { deploy.send(:load_config!) }
        assert_equal 1, error.status
      end
      assert_match(/YAML syntax error/, out)
      assert_match(/config\/ruby_native\.yml/, out)
    end
  end

  def test_yaml_aliases_are_permitted
    with_config_file(<<~YAML) do |deploy|
      defaults: &defaults
        icon: house
      tabs:
        - <<: *defaults
          title: Home
      ruby_native:
        app_id: app_123
    YAML
      deploy.send(:load_config!)
      assert_equal "house", deploy.instance_variable_get(:@config)[:tabs].first[:icon]
    end
  end

  private

  # Minitest 6 dropped minitest/mock, so swap singleton methods by hand.
  # Remove-then-define keeps the redefinition warnings out of the test output.
  def test_the_signal_preflight_blocks_a_deploy_with_broken_signals
    offense = RubyNative::CLI::Check::Offense.new(
      file: "app/views/pages/show.html.erb", line: 1, severity: :error, message: "Unknown signal `data-native-tab`."
    )

    output, status = capture_deploy_preflight([offense], argv: [])

    assert_equal 1, status
    assert_match "Unknown signal `data-native-tab`.", output
    assert_match "--skip-check", output
  end

  def test_skip_check_bypasses_the_signal_preflight
    offense = RubyNative::CLI::Check::Offense.new(
      file: "a.erb", line: 1, severity: :error, message: "Unknown signal `data-native-tab`."
    )

    _output, status = capture_deploy_preflight([offense], argv: ["--skip-check"])

    assert_equal 0, status
  end

  def test_a_warning_alone_does_not_block_a_deploy
    offense = RubyNative::CLI::Check::Offense.new(
      file: "a.erb", line: 1, severity: :warning, message: "2 elements carry `data-native-tabs`."
    )

    _output, status = capture_deploy_preflight([offense], argv: [])

    assert_equal 0, status
  end

  # nil means herb is missing, and a deploy must not fail over a gem the app
  # never asked for.
  def test_a_missing_herb_does_not_block_a_deploy
    _output, status = capture_deploy_preflight(nil, argv: [])

    assert_equal 0, status
  end

  def capture_deploy_preflight(offenses, argv:)
    deploy = RubyNative::CLI::Deploy.new(argv)
    status = 0

    output, = with_singleton_stub(RubyNative::CLI::Check, :signal_offenses, ->(*) { offenses }) do
      capture_io do
        deploy.send(:check_signals!) unless argv.include?("--skip-check")
      rescue SystemExit => error
        status = error.status
      end
    end

    [output, status]
  end

  def with_singleton_stub(receiver, name, replacement)
    original = receiver.method(name)
    own = receiver.singleton_class.instance_methods(false).include?(name)
    receiver.singleton_class.send(:remove_method, name) if own
    receiver.define_singleton_method(name, &replacement)
    yield
  ensure
    receiver.singleton_class.send(:remove_method, name)
    receiver.define_singleton_method(name, original) if own
  end

  # Single-platform by default: `deploy` with no flags now means every
  # configured platform, which fetch_latest_build answers in a different shape.
  def build_deploy(latest_build: {}, gem_version: nil, argv: ["--ios"])
    latest_build = latest_build&.merge("gem_version" => gem_version)
    deploy = RubyNative::CLI::Deploy.new(argv)
    deploy.define_singleton_method(:fetch_latest_build) { |_app_id| latest_build }
    deploy
  end

  def all_platform_deploy(latest)
    deploy = RubyNative::CLI::Deploy.new([])
    deploy.define_singleton_method(:fetch_latest_build) { |_app_id| latest }
    deploy
  end

  def stubbed_deploy(argv)
    deploy = RubyNative::CLI::Deploy.new(argv)
    deploy.define_singleton_method(:load_config!) {}
    deploy.define_singleton_method(:ensure_authenticated!) {}
    deploy
  end

  def poll_deploy
    deploy = RubyNative::CLI::Deploy.new([])
    deploy.define_singleton_method(:sleep) { |_| }
    deploy
  end

  def poll_both(deploy)
    deploy.send(
      :poll_build_status,
      "app_123",
      { "id" => 1, "status" => "queued", "platform" => "ios" },
      [{ "id" => 2, "status" => "queued", "platform" => "android" }]
    )
  end

  def trigger_deploy(response)
    deploy = RubyNative::CLI::Deploy.new([])
    deploy.define_singleton_method(:make_request) { |_uri, _req| response }
    deploy
  end

  def http_response(klass, code, body: "")
    response = klass.new("1.1", code, code)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  def with_config_file(yaml)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p("config")
        File.write("config/ruby_native.yml", yaml)
        yield RubyNative::CLI::Deploy.new([])
      end
    end
  end
end
