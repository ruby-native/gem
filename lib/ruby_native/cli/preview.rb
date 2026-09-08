require "open3"
require "net/http"
require "uri"
require "resolv"
require "ruby_native/cli/credentials"

module RubyNative
  class CLI
    class Preview
      TUNNEL_URL_PATTERN = %r{https://[a-z0-9-]+\.trycloudflare\.com}
      CONFIG_PATH = "/native/config.json"
      TUNNEL_READY_TIMEOUT = 60
      TUNNEL_POLL_INTERVAL = 1
      PUBLIC_NAMESERVERS = ["1.1.1.1", "8.8.8.8"].freeze
      DEFAULT_PORT = 3000
      PORT_RANGE = (1..65_535)
      OUTPUT_TAIL_LINES = 5
      DEPLOY_URL = "https://rubynative.com/deploy"
      QR_QUIET_ZONE = 4

      def initialize(argv)
        @url = parse_option(argv, "--url")
        @port, @port_from_env = resolve_port(argv)
        @upstream = @url || "http://localhost:#{@port}"
      end

      def run
        check_cloudflared!
        check_upstream!
        start_tunnel
      end

      private

      def check_upstream!
        uri = URI("#{@upstream}#{CONFIG_PATH}")
        response = fetch_config_response(uri)

        if config_missing?(response)
          puts "Rails server is reachable at #{upstream_description}, but it has no Ruby Native config."
          puts ""
          puts "config/ruby_native.yml is missing or empty. Create it with:"
          puts "  bin/rails generate ruby_native:install"
          puts ""
          puts "Then restart your Rails server and run `ruby_native preview` again."
          exit 1
        end

        return if response.is_a?(Net::HTTPSuccess)

        puts "Rails server is reachable at #{upstream_description}, but #{CONFIG_PATH} returned #{response.code}."
        puts ""

        # 404 is what an unmounted engine returns; any other code means the app
        # answered, so the mount is not the thing to go re-verify.
        case response
        when Net::HTTPNotFound
          puts "Make sure the ruby_native gem is installed and mounted:"
          puts "  https://rubynative.com/docs/setup"
        when Net::HTTPRedirection
          puts "Something redirected the request to #{response["location"]}."
          puts "Look for a force_ssl setting or a before_action that catches this path."
        else
          puts "Your Rails app returned an error. Open #{@upstream} in a browser and fix"
          puts "what it reports, then try again. Pending migrations are a common cause:"
          puts ""
          puts "  bin/rails db:migrate"
        end
        exit 1
      rescue Errno::ECONNREFUSED
        if @url
          puts "Could not connect to #{@url}."
          puts ""
          puts "Make sure your Rails server is reachable at that URL."
        else
          puts "Nothing is running on port #{port_description}."
          puts ""
          puts "Start your Rails server in another terminal:"
          puts "  bin/rails server -p #{@port}"
        end
        exit 1
      rescue => e
        puts "Could not reach #{@upstream}#{CONFIG_PATH}: #{e.message}"
        exit 1
      end

      # An older gem serves 200 "null" when config/ruby_native.yml is missing;
      # current gems serve 404 with the version header still set. Both mean the
      # same thing: mounted, but nothing to serve.
      def config_missing?(response)
        case response
        when Net::HTTPSuccess
          response.body.to_s.strip == "null"
        when Net::HTTPNotFound
          !response["X-Ruby-Native-Version"].nil?
        else
          false
        end
      end

      def fetch_config_response(uri, ip: nil)
        http = Net::HTTP.new(uri.host, uri.port)
        http.ipaddr = ip if ip
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = 2
        http.read_timeout = 5
        http.start { http.get(uri.request_uri) }
      end

      def wait_for_tunnel(url)
        uri = URI("#{url}#{CONFIG_PATH}")
        deadline = monotonic_now + TUNNEL_READY_TIMEOUT
        ip = nil

        print "Waiting for tunnel..."
        loop do
          begin
            ip ||= resolve_via_public_dns(uri.host)
            response = fetch_config_response(uri, ip: ip)
            if response.is_a?(Net::HTTPSuccess)
              puts " ready."
              return
            end
          rescue Resolv::ResolvError, Resolv::ResolvTimeout, StandardError
            # Keep polling.
          end

          if monotonic_now >= deadline
            puts ""
            puts "Tunnel did not respond within #{TUNNEL_READY_TIMEOUT}s at #{url}."
            puts "Showing the URL anyway. It may take a few more seconds before scanning works."
            return
          end

          print "."
          sleep TUNNEL_POLL_INTERVAL
        end
      end

      def resolve_via_public_dns(host)
        resolver = Resolv::DNS.new(nameserver: PUBLIC_NAMESERVERS)
        resolver.timeouts = [2, 4]
        addresses = resolver.getaddresses(host)
        raise Resolv::ResolvError, "no A/AAAA record for #{host}" if addresses.empty?
        addresses.first.to_s
      ensure
        resolver&.close
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # --port, then PORT, then 3000 is the precedence rails server itself uses,
      # so a preview lands on the port the app is already serving. Anything
      # unusable in PORT falls back rather than failing: the variable gets set
      # for plenty of reasons that have nothing to do with a local Rails server.
      def resolve_port(argv)
        flag = parse_option(argv, "--port")
        return [flag.to_i, false] if flag

        env = env_port
        env ? [env, true] : [DEFAULT_PORT, false]
      end

      def env_port
        value = ENV["PORT"].to_s.strip
        return unless value.match?(/\A\d+\z/)

        port = value.to_i
        port if PORT_RANGE.cover?(port)
      end

      # Naming the source keeps a port nobody typed from reading as a bug.
      def port_description
        @port_from_env ? "#{@port} (from PORT)" : @port.to_s
      end

      # @port_from_env can be true alongside --url, which ignores the port.
      def upstream_description
        return @upstream if @url || !@port_from_env

        "#{@upstream} (port from PORT)"
      end

      def parse_option(argv, flag)
        index = argv.index(flag)
        index ? argv[index + 1] : nil
      end

      def check_cloudflared!
        unless system("which cloudflared > /dev/null 2>&1")
          puts "cloudflared is not installed."
          puts ""
          puts "Install it with Homebrew:"
          puts "  brew install cloudflare/cloudflare/cloudflared"
          puts ""
          puts "Or see: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
          exit 1
        end
      end

      def start_tunnel
        puts "Starting tunnel to #{@upstream}..."
        if @url
          puts "Make sure your Rails server is reachable at #{@url}."
        else
          puts "Make sure your Rails server is running on port #{port_description} in another terminal."
        end
        puts ""

        output, wait_thread = spawn_tunnel

        @tunnel_pid = wait_thread.pid
        trap_interrupt

        tunnel_url = nil
        recent_output = []

        output.each_line do |line|
          recent_output << line.strip
          recent_output.shift if recent_output.length > OUTPUT_TAIL_LINES
          if tunnel_url.nil? && line =~ TUNNEL_URL_PATTERN
            tunnel_url = line[TUNNEL_URL_PATTERN]
            wait_for_tunnel(tunnel_url)
            display_qr(tunnel_url)
          end
        end

        # Ctrl+C exits inside the trap, so reaching here means cloudflared
        # itself stopped. Silence looked like either a hang or a clean exit.
        report_tunnel_exit(tunnel_url, wait_thread.value, recent_output)
      rescue Interrupt
        # Handled by trap
      ensure
        kill_tunnel
      end

      def spawn_tunnel
        stdin, stdout_err, wait_thread = Open3.popen2e(
          "cloudflared", "tunnel", "--url", @upstream
        )
        stdin.close
        [stdout_err, wait_thread]
      end

      def report_tunnel_exit(tunnel_url, status, recent_output)
        puts ""
        if tunnel_url
          puts "The tunnel stopped: cloudflared exited (#{describe_exit(status)})."
        else
          puts "cloudflared exited (#{describe_exit(status)}) before the tunnel came up."
        end

        unless recent_output.empty?
          puts ""
          puts "Last output from cloudflared:"
          recent_output.each { |line| puts "  #{line}" }
        end

        puts ""
        puts "This usually means cloudflared could not reach Cloudflare. Check your"
        puts "internet connection and run `ruby_native preview` again."
        exit 1
      end

      def describe_exit(status)
        status.exitstatus ? "status #{status.exitstatus}" : status.to_s
      end

      def display_qr(url)
        require "rqrcode"

        qr = RQRCode::QRCode.new(url, level: :l)
        width = (qr.modules.size + QR_QUIET_ZONE * 2) * 2
        columns = terminal_columns

        # A row that wraps prints as two, and the code never scans. Longer tunnel
        # hostnames make bigger codes, so a pane that fit yesterday can fail today.
        if columns && columns < width
          puts ""
          puts "Your terminal is #{columns} columns wide and the QR code needs #{width}. Widen the window, or paste the URL into the Ruby Native app."
          print_preview_details(url)
          return
        end

        # Painted as background colors, not block glyphs: a glyph takes the terminal's
        # foreground color, which prints the code inverted on a dark theme, and Android
        # (unlike iOS) will not decode an inverted code. Truecolor rather than any
        # palette index, because terminals remap both the 16 basic colors and the 256
        # cube, which is how "white" came out as a mid-gray in one terminal and as
        # orange in another. 24-bit RGB is a literal value with no lookup, so the
        # contrast and the polarity are the same everywhere.
        puts ""
        print qr.as_ansi(
          light: "\e[48;2;255;255;255m",
          dark: "\e[48;2;0;0;0m",
          quiet_zone_size: QR_QUIET_ZONE
        )
        print_preview_details(url)
      end

      def print_preview_details(url)
        puts ""
        puts url
        puts ""
        puts "Download the Ruby Native app and scan the QR code: https://rubynative.com/try/download"
        puts ""
        if @url
          puts "Keep this running and your Rails server reachable at #{@url}. Press Ctrl+C to stop."
        else
          puts "Keep this running and your Rails server on port #{port_description} in another terminal. Press Ctrl+C to stop."
        end
      end

      # Only a terminal can wrap the code; captured or piped output never does.
      def terminal_columns
        return unless $stdout.tty?

        require "io/console"
        IO.console&.winsize&.last
      rescue StandardError
        nil
      end

      # Nobody has deployed from a machine that has never logged in, so the
      # hint reaches first-time users and spares customers previewing day to day.
      def never_logged_in?
        Credentials.token.nil?
      end

      def print_farewell
        return unless never_logged_in?

        puts ""
        puts "Like what you see? `ruby_native deploy` puts a real app on your phone for good."
        puts ""
        puts "Free until you ship: #{DEPLOY_URL}"
      end

      def trap_interrupt
        Signal.trap("INT") do
          print_farewell
          kill_tunnel
          exit 0
        end
      end

      def kill_tunnel
        return unless @tunnel_pid
        Process.kill("TERM", @tunnel_pid)
        Process.wait(@tunnel_pid)
      rescue Errno::ESRCH, Errno::ECHILD
        # Process already exited.
      end
    end
  end
end
