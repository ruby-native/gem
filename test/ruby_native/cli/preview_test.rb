require "minitest/autorun"
require "json"
require "tmpdir"
require "ruby_native/cli/preview"

class PreviewTest < Minitest::Test
  def setup
    @preview = RubyNative::CLI::Preview.new(["--port", "3000"])
  end

  def test_defaults_to_port_3000
    with_port(nil) { assert_equal "http://localhost:3000", upstream_for([]) }
  end

  def test_takes_the_port_from_the_environment
    with_port("3001") { assert_equal "http://localhost:3001", upstream_for([]) }
  end

  def test_port_flag_wins_over_the_environment
    with_port("3001") { assert_equal "http://localhost:4000", upstream_for(["--port", "4000"]) }
  end

  def test_url_flag_ignores_the_environment
    with_port("3001") { assert_equal "https://app.test", upstream_for(["--url", "https://app.test"]) }
  end

  def test_unusable_environment_ports_fall_back_to_the_default
    ["", "  ", "tcp://10.0.0.1:3001", "3001abc", "0", "99999"].each do |value|
      with_port(value) do
        assert_equal "http://localhost:3000", upstream_for([]), "PORT=#{value.inspect}"
      end
    end
  end

  def test_messages_name_the_environment_as_the_source_of_an_inherited_port
    with_port("3001") do
      preview = RubyNative::CLI::Preview.new([])
      preview.define_singleton_method(:fetch_config_response) { |_uri| raise Errno::ECONNREFUSED }
      out, _err = capture_io do
        assert_raises(SystemExit) { preview.send(:check_upstream!) }
      end
      assert_match(/Nothing is running on port 3001 \(from PORT\)/, out)
      assert_match(/bin\/rails server -p 3001/, out)
    end
  end

  # An inherited port answering 404 is likely some other local service, not an
  # unmounted gem, so the message has to say where the port came from.
  def test_the_wrong_service_message_names_the_environment_as_the_source_too
    with_port("3001") do
      preview = RubyNative::CLI::Preview.new([])
      preview.define_singleton_method(:fetch_config_response) { |_uri| Net::HTTPNotFound.new("1.1", "404", "Not Found") }
      out, _err = capture_io do
        assert_raises(SystemExit) { preview.send(:check_upstream!) }
      end
      assert_match(%r{reachable at http://localhost:3001 \(port from PORT\)}, out)
    end
  end

  def test_the_wrong_service_message_does_not_blame_the_environment_for_a_flag_port
    with_port("3001") do
      preview = RubyNative::CLI::Preview.new(["--port", "4000"])
      preview.define_singleton_method(:fetch_config_response) { |_uri| Net::HTTPNotFound.new("1.1", "404", "Not Found") }
      out, _err = capture_io do
        assert_raises(SystemExit) { preview.send(:check_upstream!) }
      end
      assert_match(%r{reachable at http://localhost:4000, but}, out)
      refute_match(/from PORT/, out)
    end
  end

  # The QR screen is the last thing printed, seconds after the same port was
  # named with its source, so it has to agree.
  def test_the_qr_reminder_names_the_environment_as_the_source_too
    with_port("3001") do
      preview = RubyNative::CLI::Preview.new([])
      out, _err = capture_io do
        preview.send(:display_qr, "https://example.trycloudflare.com")
      end
      assert_match(/your Rails server on port 3001 \(from PORT\)/, out)
    end
  end

  def test_passes_when_config_endpoint_returns_200
    stub_http_response(http_response(Net::HTTPSuccess, "200", body: '{"app":{"name":"Test"}}'))
    @preview.send(:check_upstream!)
  end

  # An old gem answers 200 "null" when config/ruby_native.yml is missing, which
  # used to sail through as "ready" and fail later on the phone.
  def test_exits_when_config_endpoint_serves_null
    stub_http_response(http_response(Net::HTTPSuccess, "200", body: "null"))
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(/missing or empty/, out)
    assert_match(/ruby_native:install/, out)
  end

  # A 404 carrying the gem's version header comes from the engine itself, so
  # the mount is fine and the config file is what's missing.
  def test_a_404_from_the_gem_means_missing_config_not_a_bad_mount
    response = http_response(Net::HTTPNotFound, "404")
    response["X-Ruby-Native-Version"] = "0.13.0"
    stub_http_response(response)
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(/missing or empty/, out)
    refute_match(/installed and mounted/, out)
  end

  def test_exits_when_config_endpoint_returns_404
    stub_http_response(Net::HTTPNotFound.new("1.1", "404", "Not Found"))
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(/returned 404/, out)
    assert_match(/installed and mounted/, out)
    assert_match(%r{https://rubynative\.com/docs/setup}, out)
  end

  # A correctly mounted gem returns 500 for plenty of ordinary reasons, so
  # blaming the mount sends people to re-verify one that was already fine.
  def test_exits_when_config_endpoint_returns_500
    stub_http_response(Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error"))
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(/returned 500/, out)
    assert_match(/Your Rails app returned an error/, out)
    assert_match(/bin\/rails db:migrate/, out)
    refute_match(/installed and mounted/, out)
  end

  def test_exits_and_names_the_destination_when_config_endpoint_redirects
    response = Net::HTTPFound.new("1.1", "302", "Found")
    response["location"] = "https://example.test/sign_in"
    stub_http_response(response)
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(%r{redirected the request to https://example\.test/sign_in}, out)
    refute_match(/installed and mounted/, out)
    refute_match(/db:migrate/, out)
  end

  def test_exits_when_server_not_running
    stub_http_raise(Errno::ECONNREFUSED)
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(/Nothing is running on port 3000/, out)
    refute_match(/from PORT/, out)
  end

  def test_exits_when_url_unreachable
    preview = RubyNative::CLI::Preview.new(["--url", "https://rails.example.orb.local"])
    preview.define_singleton_method(:fetch_config_response) { |_uri| raise Errno::ECONNREFUSED }
    out, _err = capture_io do
      assert_raises(SystemExit) { preview.send(:check_upstream!) }
    end
    assert_match(%r{Could not connect to https://rails\.example\.orb\.local}, out)
  end

  def test_exits_on_unexpected_error
    stub_http_raise(SocketError.new("getaddrinfo failed"))
    out, _err = capture_io do
      assert_raises(SystemExit) { @preview.send(:check_upstream!) }
    end
    assert_match(/Could not reach/, out)
  end

  def test_wait_for_tunnel_returns_when_ready
    stub_dns("1.2.3.4")
    @preview.define_singleton_method(:fetch_config_response) { |_uri, ip: nil| Net::HTTPSuccess.new("1.1", "200", "OK") }
    @preview.define_singleton_method(:sleep) { |_| }
    out, _err = capture_io do
      @preview.send(:wait_for_tunnel, "https://example.trycloudflare.com")
    end
    assert_match(/Waiting for tunnel\.\.\. ready\./, out)
  end

  def test_wait_for_tunnel_polls_until_success
    stub_dns("1.2.3.4")
    responses = [
      Net::HTTPNotFound.new("1.1", "404", "Not Found"),
      Net::HTTPNotFound.new("1.1", "404", "Not Found"),
      Net::HTTPSuccess.new("1.1", "200", "OK")
    ]
    @preview.define_singleton_method(:fetch_config_response) { |_uri, ip: nil| responses.shift }
    @preview.define_singleton_method(:sleep) { |_| }
    out, _err = capture_io do
      @preview.send(:wait_for_tunnel, "https://example.trycloudflare.com")
    end
    assert_match(/Waiting for tunnel\.\.\.\.\. ready\./, out)
    assert_empty responses
  end

  def test_wait_for_tunnel_keeps_polling_after_dns_failure
    lookups = [Resolv::ResolvError.new("no A record"), "1.2.3.4"]
    @preview.define_singleton_method(:resolve_via_public_dns) do |_host|
      result = lookups.shift
      raise result if result.is_a?(Exception)
      result
    end
    @preview.define_singleton_method(:fetch_config_response) { |_uri, ip: nil| Net::HTTPSuccess.new("1.1", "200", "OK") }
    @preview.define_singleton_method(:sleep) { |_| }
    out, _err = capture_io do
      @preview.send(:wait_for_tunnel, "https://example.trycloudflare.com")
    end
    assert_match(/Waiting for tunnel\.\.\.\. ready\./, out)
    assert_empty lookups
  end

  def test_wait_for_tunnel_gives_up_after_timeout
    stub_dns("1.2.3.4")
    @preview.define_singleton_method(:fetch_config_response) { |_uri, ip: nil| Net::HTTPNotFound.new("1.1", "404", "Not Found") }
    @preview.define_singleton_method(:sleep) { |_| }
    times = [0, 5, 70]
    @preview.define_singleton_method(:monotonic_now) { times.shift || 999 }
    out, _err = capture_io do
      @preview.send(:wait_for_tunnel, "https://example.trycloudflare.com")
    end
    assert_match(/did not respond within 60s/, out)
  end

  def test_tunnel_exit_before_url_prints_status_and_last_output
    preview = tunnel_preview(
      "2026-08-13 INF Requesting new quick Tunnel on trycloudflare.com...\n" \
      "2026-08-13 ERR failed to request quick Tunnel: lookup api.trycloudflare.com: no such host\n",
      exitstatus: 1
    )

    out, _err = capture_io do
      error = assert_raises(SystemExit) { preview.send(:start_tunnel) }
      assert_equal 1, error.status
    end
    assert_match(/cloudflared exited \(status 1\) before the tunnel came up/, out)
    assert_match(/failed to request quick Tunnel/, out)
    assert_match(/run `ruby_native preview` again/, out)
  end

  def test_tunnel_death_after_the_url_is_reported_not_silent
    preview = tunnel_preview(
      "https://example.trycloudflare.com\n" \
      "2026-08-13 ERR connection terminated\n",
      exitstatus: 1
    )
    preview.define_singleton_method(:wait_for_tunnel) { |_url| }
    preview.define_singleton_method(:display_qr) { |_url| }

    out, _err = capture_io do
      assert_raises(SystemExit) { preview.send(:start_tunnel) }
    end
    assert_match(/The tunnel stopped/, out)
    assert_match(/connection terminated/, out)
  end

  def test_display_qr_links_to_the_app_download_page
    out, _err = capture_io do
      @preview.send(:display_qr, "https://example.trycloudflare.com")
    end
    assert_match(%r{Download the Ruby Native app and scan the QR code}, out)
    assert_match(%r{https://rubynative\.com/try/download}, out)
    refute_match(/Preview app/, out)
  end

  # Block glyphs take the terminal's foreground color, so a dark theme printed the
  # code inverted and ZXing on Android refused to decode it.
  def test_display_qr_sets_backgrounds_rather_than_drawing_glyphs
    out, _err = capture_io do
      @preview.send(:display_qr, "https://example.trycloudflare.com")
    end
    assert_includes out, "\e[48;2;255;255;255m"
    assert_includes out, "\e[48;2;0;0;0m"
    refute_includes out, "█"
  end

  # Terminals remap both the 16 basic colors and the 256-color cube, which turned
  # "white" into a mid-gray in one terminal and orange in another. Only literal RGB
  # renders the same everywhere, so no palette index may creep back in.
  def test_display_qr_uses_no_palette_indexes
    out, _err = capture_io do
      @preview.send(:display_qr, "https://example.trycloudflare.com")
    end
    refute_includes out, "\e[47m"
    refute_includes out, "\e[40m"
    refute_match(/\e\[48;5;/, out)
  end

  def test_display_qr_quiet_zone_is_four_modules_on_every_side
    url = "https://example.trycloudflare.com"
    out, _err = capture_io { @preview.send(:display_qr, url) }

    light = "\e[48;2;255;255;255m"
    dark_bg = "\e[48;2;0;0;0m"
    rows = out.split("\e[m\n").select { |row| row.include?("\e[48;2;") }
    grid = rows.map do |row|
      cells = []
      dark = nil
      row.scan(/\e\[48;2;(?:255;255;255|0;0;0)m|  /) do |token|
        case token
        when light then dark = false
        when dark_bg then dark = true
        else cells << dark
        end
      end
      cells
    end

    size = RQRCode::QRCode.new(url, level: :l).modules.length
    assert_equal size + 8, grid.length
    assert_equal [size + 8], grid.map(&:length).uniq

    light = ->(cells) { cells.all? { |cell| cell == false } }
    assert light.call(grid.first(4).flatten), "top quiet zone"
    assert light.call(grid.last(4).flatten), "bottom quiet zone"
    assert light.call(grid[4...-4].flat_map { |row| row.first(4) }), "left quiet zone"
    assert light.call(grid[4...-4].flat_map { |row| row.last(4) }), "right quiet zone"
  end


  def test_a_narrow_terminal_gets_a_note_instead_of_a_wrapped_code
    out, _err = with_terminal_columns(60) do
      capture_io { @preview.send(:display_qr, "https://example.trycloudflare.com") }
    end

    assert_match "Your terminal is 60 columns wide and the QR code needs 74.", out
    refute_match "\e[48;2;0;0;0m", out
    assert_match "https://example.trycloudflare.com", out
    assert_match "Download the Ruby Native app and scan the QR code", out
  end

  def test_a_wide_terminal_gets_the_code
    out, _err = with_terminal_columns(120) do
      capture_io { @preview.send(:display_qr, "https://example.trycloudflare.com") }
    end

    assert_match "\e[48;2;0;0;0m", out
    refute_match "columns wide", out
  end

  def test_an_unknown_terminal_width_still_prints_the_code
    out, _err = with_terminal_columns(nil) do
      capture_io { @preview.send(:display_qr, "https://example.trycloudflare.com") }
    end

    assert_match "\e[48;2;0;0;0m", out
  end

  def test_the_qr_screen_is_download_scan_and_keep_running
    out, _err = capture_io { @preview.send(:display_qr, "https://example.trycloudflare.com") }

    assert_match "Download the Ruby Native app and scan the QR code: https://rubynative.com/try/download", out
    assert_match "in another terminal. Press Ctrl+C to stop.", out
    refute_match "rubynative.com/deploy", out
  end

  def test_ctrl_c_points_a_first_time_user_at_deploy
    without_credentials do
      out, _err = capture_io { @preview.send(:print_farewell) }
      assert_match "Like what you see? `ruby_native deploy` puts a real app on your phone for good.", out
      assert_match "Free until you ship: https://rubynative.com/deploy", out
    end
  end

  def test_ctrl_c_is_quiet_once_logged_in
    with_credentials do
      out, _err = capture_io { @preview.send(:print_farewell) }
      assert_empty out
    end
  end

  private

  def http_response(klass, code, body: "")
    response = klass.new("1.1", code, code)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  # start_tunnel with a canned process: stubbing the trap and the kill keeps the
  # test from touching real signals or PIDs.
  def tunnel_preview(output, exitstatus:)
    preview = RubyNative::CLI::Preview.new(["--port", "3000"])
    status = Struct.new(:exitstatus).new(exitstatus)
    thread = Struct.new(:pid, :value).new(4242, status)
    preview.define_singleton_method(:spawn_tunnel) { [StringIO.new(output), thread] }
    preview.define_singleton_method(:trap_interrupt) {}
    preview.define_singleton_method(:kill_tunnel) {}
    preview
  end

  def upstream_for(argv)
    RubyNative::CLI::Preview.new(argv).instance_variable_get(:@upstream)
  end

  def with_port(value)
    original = ENV["PORT"]
    ENV["PORT"] = value
    yield
  ensure
    ENV["PORT"] = original
  end

  def stub_http_response(response)
    @preview.define_singleton_method(:fetch_config_response) { |_uri| response }
  end

  def stub_http_raise(error)
    @preview.define_singleton_method(:fetch_config_response) { |_uri| raise error }
  end

  def stub_dns(ip)
    @preview.define_singleton_method(:resolve_via_public_dns) { |_host| ip }
  end

  def without_credentials(&block)
    swap_credentials(nil, &block)
  end

  def with_credentials(&block)
    swap_credentials("a-token", &block)
  end

  def swap_credentials(token)
    original_path = RubyNative::CLI::Credentials.path
    original_env = ENV.delete("RUBY_NATIVE_TOKEN")
    Dir.mktmpdir do |dir|
      RubyNative::CLI::Credentials.path = File.join(dir, "credentials")
      File.write(RubyNative::CLI::Credentials.path, JSON.generate(token: token)) if token
      yield
    end
  ensure
    RubyNative::CLI::Credentials.path = original_path
    ENV["RUBY_NATIVE_TOKEN"] = original_env if original_env
  end


  def with_terminal_columns(columns)
    @preview.define_singleton_method(:terminal_columns) { columns }
    yield
  ensure
    @preview.singleton_class.remove_method(:terminal_columns)
  end

end
