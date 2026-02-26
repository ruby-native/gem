require "open3"

module RubyNative
  class CLI
    class Preview
      TUNNEL_URL_PATTERN = %r{https://[a-z0-9-]+\.trycloudflare\.com}

      BLACK_BG = "\033[40m"
      WHITE_BG = "\033[107m"
      BLACK_FG = "\033[30m"
      WHITE_FG = "\033[97m"
      RESET = "\033[0m"

      def initialize(argv)
        @port = parse_port(argv)
      end

      def run
        check_cloudflared!
        start_tunnel
      end

      private

      def parse_port(argv)
        index = argv.index("--port")
        if index
          argv[index + 1]&.to_i || 3000
        else
          3000
        end
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
        puts "Starting tunnel to http://localhost:#{@port}..."
        puts "Make sure your Rails server is running on port #{@port} in another terminal."
        puts ""

        stdin, stdout_err, wait_thread = Open3.popen2e(
          "cloudflared", "tunnel", "--url", "http://localhost:#{@port}"
        )
        stdin.close

        @tunnel_pid = wait_thread.pid
        trap_interrupt

        tunnel_url = nil

        stdout_err.each_line do |line|
          if line =~ TUNNEL_URL_PATTERN
            tunnel_url = line[TUNNEL_URL_PATTERN]
            display_qr(tunnel_url)
          end
        end
      rescue Interrupt
        # Handled by trap
      ensure
        kill_tunnel
      end

      def display_qr(url)
        require "rqrcode"

        qr = RQRCode::QRCode.new(url)
        modules = qr.modules

        print "\033[2J\033[H" # Clear terminal

        # Use Unicode half-block characters to render two QR rows per
        # terminal row, cutting the height in half for square proportions.
        quiet = 1
        size = modules.length
        total = size + quiet * 2

        lines = []

        (0...total).step(2) do |r|
          line = ""
          total.times do |c|
            top = pixel_dark?(modules, r, c, quiet, size)
            bottom = pixel_dark?(modules, r + 1, c, quiet, size)

            if top && bottom
              line << "#{BLACK_BG} #{RESET}"
            elsif top
              line << "#{BLACK_BG}#{WHITE_FG}\u2584#{RESET}"
            elsif bottom
              line << "#{WHITE_BG}#{BLACK_FG}\u2584#{RESET}"
            else
              line << "#{WHITE_BG} #{RESET}"
            end
          end
          lines << line
        end

        puts lines.join("\n")
        puts ""
        puts url
        puts ""
        puts "Scan with the Ruby Native preview app."
        puts "Keep this running and your Rails server on port #{@port} in another terminal."
        puts "Press Ctrl+C to stop."
      end

      def trap_interrupt
        Signal.trap("INT") do
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

      def pixel_dark?(modules, row, col, quiet, size)
        r = row - quiet
        c = col - quiet
        r >= 0 && r < size && c >= 0 && c < size && modules[r][c]
      end
    end
  end
end
