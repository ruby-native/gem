require "json"
require "open3"
require "fileutils"
require "tempfile"
require "net/http"
require "uri"
require "ruby_native/cli/credentials"

module RubyNative
  class CLI
    class Screenshots
      STORAGE_DIR = ".ruby_native"
      STORAGE_FILE = "screenshots_storage.json"
      OUTPUT_DIR = ".ruby_native/screenshots"
      CONFIG_PATH = "config/ruby_native.yml"
      SCALE = 3
      WIDTH_PX = 1320
      HEIGHT_PX = 2868
      WIDTH_PT = WIDTH_PX / SCALE  # 440
      HEIGHT_PT = HEIGHT_PX / SCALE # 956

      HOST = ENV.fetch("RUBY_NATIVE_HOST", "https://rubynative.com")

      def initialize(argv)
        @url = parse_option(argv, "--url", nil)
        @port = parse_option(argv, "--port", nil)
        @output = parse_option(argv, "--output", OUTPUT_DIR)
        @login = argv.delete("--login")

        if @url
          unless @url.match?(%r{\Ahttps?://})
            host = @url.split(":", 2).first
            scheme = (host == "localhost" || host.match?(/\A\d+\.\d+\.\d+\.\d+\z/)) ? "http" : "https"
            @url = "#{scheme}://#{@url}"
          end
          @url = @url.chomp("/")
          @port = URI(@url).port if @port.nil?
        else
          @port = (@port || 3000).to_i
        end
      end

      def run
        load_config!
        check_node!
        check_playwright!

        if @login
          run_login
        else
          run_setup unless screenshots_configured?
          check_server!
          capture_screenshots
          upload_screenshots if credentials_available?
        end
      end

      private

      def parse_option(argv, flag, default)
        index = argv.index(flag)
        if index
          argv.delete_at(index)
          argv.delete_at(index) || default
        else
          default
        end
      end

      # --- Config ---

      def load_config!
        unless File.exist?(CONFIG_PATH)
          puts "config/ruby_native.yml not found. Run `rails generate ruby_native:install` first."
          exit 1
        end

        require "yaml"
        @config = YAML.load_file(CONFIG_PATH, symbolize_names: true) || {}
      end

      def screenshots_configured?
        paths = @config.dig(:screenshots, :paths)
        paths.is_a?(Array) && !paths.empty?
      end

      def screenshot_paths
        @config.dig(:screenshots, :paths) || []
      end

      def tab_paths
        tabs = @config[:tabs] || []
        tabs.map { |tab| tab[:path] }.compact
      end

      # --- First-run setup ---

      def run_setup
        puts "Let's set up screenshots! (one-time)"
        puts ""

        paths = prompt_for_paths
        write_paths_to_config(paths)
        prompt_for_login

        puts ""
      end

      def prompt_for_paths
        tabs = tab_paths

        if tabs.any?
          puts "Which paths do you want to capture?"
          puts "Your tabs: #{tabs.join(", ")}"
          puts "Enter paths (comma-separated) or press Enter to use tab paths:"
        else
          puts "Which paths do you want to capture?"
          puts "Enter paths (comma-separated):"
        end

        print "> "
        input = $stdin.gets&.strip || ""

        if input.empty?
          if tabs.any?
            tabs
          else
            puts "No paths entered and no tabs configured."
            exit 1
          end
        else
          input.split(",").map(&:strip).reject(&:empty?).map { |p| p.start_with?("/") ? p : "/#{p}" }
        end
      end

      def write_paths_to_config(paths)
        raw = File.read(CONFIG_PATH)

        yaml_paths = paths.map { |p| "    - #{p}" }.join("\n")
        screenshot_block = "\nscreenshots:\n  paths:\n#{yaml_paths}\n"

        File.write(CONFIG_PATH, raw.rstrip + "\n" + screenshot_block)

        # Reload config
        require "yaml"
        @config = YAML.load_file(CONFIG_PATH, symbolize_names: true) || {}

        puts ""
        puts "Added to #{CONFIG_PATH}:"
        puts ""
        puts "  screenshots:"
        puts "    paths:"
        paths.each { |p| puts "      - #{p}" }
      end

      def prompt_for_login
        puts ""
        puts "Does your app require sign-in? (y/n)"
        print "> "
        input = $stdin.gets&.strip&.downcase || ""

        if input == "y" || input == "yes"
          puts ""
          run_login
        end
      end

      # --- Checks ---

      def check_node!
        _, _, status = Open3.capture3("node", "--version")
        unless status.success?
          puts "Node.js is required for screenshots. Install it from https://nodejs.org"
          exit 1
        end
      end

      def check_server!
        uri = URI("#{base_url}/")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.request(Net::HTTP::Head.new(uri))
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError, Net::OpenTimeout
        if @url
          puts "Could not reach #{@url}."
        else
          puts "No server running on port #{@port}."
          puts ""
          puts "Start your Rails server first:"
          puts "  bin/rails server#{" -p #{@port}" if @port != 3000}"
        end
        puts ""
        puts "Then run this command again."
        exit 1
      end

      def check_playwright!
        FileUtils.mkdir_p(STORAGE_DIR)
        add_to_gitignore

        playwright_dir = File.join(STORAGE_DIR, "node_modules", "playwright")
        unless File.exist?(playwright_dir)
          puts "Playwright is required for screenshots."
          puts "Install it now? (y/n)"
          print "> "
          input = $stdin.gets&.strip&.downcase || ""
          exit 0 unless input == "y" || input == "yes"

          puts ""
          puts "Installing Playwright..."
          system("npm", "install", "--prefix", STORAGE_DIR, "playwright", out: File::NULL, err: File::NULL)

          puts "Installing WebKit browser..."
          system("npx", "--prefix", STORAGE_DIR, "playwright", "install", "webkit", out: File::NULL)

          unless File.exist?(playwright_dir)
            puts ""
            puts "Failed to install Playwright. Install it manually:"
            puts "  npm install playwright"
            puts "  npx playwright install webkit"
            exit 1
          end

          puts ""
        end
      end

      def base_url
        @url || "http://localhost:#{@port}"
      end

      # --- Login ---

      def run_login
        puts "Opening browser to #{base_url}..."
        puts "Sign in to your app, then close the browser window."
        puts ""

        script = login_script
        run_playwright(script)

        if File.exist?(storage_path)
          puts ""
          puts "Session saved."
        else
          puts ""
          puts "No session saved. Try again with `ruby_native screenshots --login`."
          exit 1
        end
      end

      # --- Capture ---

      def capture_screenshots
        paths = screenshot_paths

        if paths.empty?
          puts "No screenshot paths configured in #{CONFIG_PATH}."
          puts "Run `ruby_native screenshots` to set them up, or add manually:"
          puts ""
          puts "  screenshots:"
          puts "    paths:"
          puts "      - /inbox"
          puts "      - /profile"
          exit 1
        end

        FileUtils.mkdir_p(@output)

        puts "Capturing #{paths.length} screenshot#{"s" if paths.length > 1} at #{WIDTH_PX}x#{HEIGHT_PX} (#{WIDTH_PT}x#{HEIGHT_PT}pt @#{SCALE}x)..."
        puts ""

        script = capture_script(paths)
        run_playwright(script)

        puts ""
        puts "Screenshots saved to #{@output}/."
      end

      # --- Upload ---

      def credentials_available?
        if Credentials.token
          true
        else
          puts ""
          puts "Run `ruby_native login` to upload screenshots to Ruby Native."
          false
        end
      end

      def upload_screenshots
        begin
          app_id = @config.dig(:ruby_native, :app_id)
          app_id = link_app unless app_id
          return unless app_id

          files = Dir.glob(File.join(@output, "*.png")).sort
          if files.empty?
            puts "No screenshots to upload."
            return
          end

          puts ""
          puts "Uploading #{files.length} screenshot#{"s" if files.length > 1}..."

          api_delete("/api/v1/apps/#{app_id}/web_screenshots")

          files.each_with_index do |file, index|
            path = screenshot_paths[index] || File.basename(file, ".png")
            config = compositor_config_for(path)
            api_upload("/api/v1/apps/#{app_id}/web_screenshots", file, screenshot_path: path, position: index, total: files.length, compositor_config: config)
            puts "  #{File.basename(file)}"
          end

          puts ""
          puts "Uploaded to Ruby Native."
        rescue TokenExpiredError
          puts "Token expired. Run `ruby_native login` again."
        rescue => e
          puts "Upload failed: #{e.message}"
          puts "Screenshots are saved locally in #{@output}/."
        end
      end

      def link_app
        apps = fetch_apps
        return unless apps

        if apps.empty?
          puts "No apps found on your account."
          return
        end

        app = if apps.length == 1
          puts "Using app: #{apps[0]["name"]}"
          apps[0]
        else
          puts "Which app?"
          apps.each_with_index do |a, i|
            puts "  #{i + 1}. #{a["name"]}"
          end
          print "> "
          choice = ($stdin.gets&.strip || "").to_i
          unless choice.between?(1, apps.length)
            puts "Invalid choice."
            return
          end
          apps[choice - 1]
        end

        app_id = app["public_id"]
        write_app_id_to_config(app_id)
        app_id
      end

      def write_app_id_to_config(app_id)
        raw = File.read(CONFIG_PATH)

        if raw.match?(/^ruby_native:/)
          # Append under existing ruby_native key
          raw = raw.gsub(/^(ruby_native:\s*\n)/, "\\1  app_id: #{app_id}\n")
        else
          raw = raw.rstrip + "\n\nruby_native:\n  app_id: #{app_id}\n"
        end

        File.write(CONFIG_PATH, raw)

        require "yaml"
        @config = YAML.load_file(CONFIG_PATH, symbolize_names: true) || {}
      end

      def fetch_apps
        uri = URI("#{HOST}/api/v1/apps")
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)

        case response
        when Net::HTTPUnauthorized
          raise TokenExpiredError
        when Net::HTTPSuccess
          JSON.parse(response.body)
        else
          puts "Failed to fetch apps: #{response.code}"
          nil
        end
      end

      TokenExpiredError = Class.new(StandardError)

      def api_delete(path)
        uri = URI("#{HOST}#{path}")
        req = Net::HTTP::Delete.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"

        response = make_request(uri, req)
        raise TokenExpiredError if response.is_a?(Net::HTTPUnauthorized)
        response
      end

      def compositor_config_for(path)
        tabs = (@config[:tabs] || []).map { |tab|
          {title: tab[:title], icon: tab[:icon], selected: tab[:path] == path}
        }

        appearance = @config[:appearance] || {}
        {
          tabs: tabs,
          tint_color: resolve_color(appearance[:tint_color]),
          background_color: resolve_color(appearance[:background_color])
        }.compact
      end

      def resolve_color(value)
        case value
        when Hash then value[:light] || value["light"]
        when String then value
        end
      end

      def api_upload(endpoint, file_path, screenshot_path:, position:, total:, compositor_config: nil)
        uri = URI("#{HOST}#{endpoint}")
        boundary = "RubyNative#{SecureRandom.hex(16)}"

        body = build_multipart_body(boundary, file_path, screenshot_path, position, total, compositor_config)

        req = Net::HTTP::Post.new(uri)
        req["Authorization"] = "Token #{Credentials.token}"
        req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
        req.body = body

        response = make_request(uri, req)
        raise TokenExpiredError if response.is_a?(Net::HTTPUnauthorized)

        if response.is_a?(Net::HTTPNotFound)
          puts "App not found. Clearing app_id from config."
          clear_app_id_from_config
          return
        end

        response
      end

      def build_multipart_body(boundary, file_path, path, position, total, compositor_config)
        parts = []

        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"path\"\r\n\r\n"
        parts << "#{path}\r\n"

        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"position\"\r\n\r\n"
        parts << "#{position}\r\n"

        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"total\"\r\n\r\n"
        parts << "#{total}\r\n"

        if compositor_config
          parts << "--#{boundary}\r\n"
          parts << "Content-Disposition: form-data; name=\"compositor_config\"\r\n\r\n"
          parts << "#{JSON.generate(compositor_config)}\r\n"
        end

        parts << "--#{boundary}\r\n"
        parts << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file_path)}\"\r\n"
        parts << "Content-Type: image/png\r\n\r\n"
        parts << File.binread(file_path)
        parts << "\r\n"

        parts << "--#{boundary}--\r\n"
        parts.join
      end

      def make_request(uri, req)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(req)
      end

      def clear_app_id_from_config
        raw = File.read(CONFIG_PATH)
        raw = raw.gsub(/^  app_id: .+\n/, "")
        File.write(CONFIG_PATH, raw)

        require "yaml"
        @config = YAML.load_file(CONFIG_PATH, symbolize_names: true) || {}
      end

      # --- Playwright ---

      def add_to_gitignore
        gitignore = ".gitignore"
        return unless File.exist?(gitignore)
        return if File.read(gitignore).include?(".ruby_native")

        File.open(gitignore, "a") { |f| f.puts "\n# Ruby Native\n.ruby_native/" }
      end

      def storage_path
        File.join(STORAGE_DIR, STORAGE_FILE)
      end

      def run_playwright(script)
        FileUtils.mkdir_p(STORAGE_DIR)
        script_path = File.join(STORAGE_DIR, "capture.js")
        File.write(script_path, script)

        node_path = File.expand_path(File.join(STORAGE_DIR, "node_modules"))
        env = {"NODE_PATH" => node_path}

        stdout, stderr, status = Open3.capture3(env, "node", script_path)
        puts stdout unless stdout.empty?

        unless status.success?
          puts stderr unless stderr.empty?
        end
      ensure
        File.delete(script_path) if script_path && File.exist?(script_path)
      end

      def login_script
        <<~JS
          const { webkit } = require('playwright');

          (async () => {
            const browser = await webkit.launch({ headless: false });
            const context = await browser.newContext();
            const page = await context.newPage();

            await page.goto('#{base_url}/');
            console.log('Sign in to your app, then close the browser window.');

            await page.waitForEvent('close', { timeout: 0 }).catch(() => {});
            await context.storageState({ path: '#{storage_path}' });
            await browser.close();
          })();
        JS
      end

      def capture_script(paths)
        storage_opt = if File.exist?(storage_path)
          "storageState: '#{storage_path}',"
        else
          ""
        end

        screenshots_js = paths.map.with_index { |path, i|
          safe_name = path.gsub(/[^a-z0-9]/i, "_").gsub(/^_+|_+$/, "")
          safe_name = "root" if safe_name.empty?
          output_path = File.join(@output, "#{"%02d" % (i + 1)}_#{safe_name}.png")

          <<~CAPTURE
            const response_#{i} = await page.goto('#{base_url}#{path}', { waitUntil: 'networkidle' });
            if (response_#{i} && response_#{i}.status() >= 400) {
              console.log('  #{path} -> ERROR ' + response_#{i}.status() + ' (skipped)');
            } else {
              await page.screenshot({ path: '#{output_path}' });
              console.log('  #{path} -> #{output_path}');
            }
          CAPTURE
        }.join("\n")

        <<~JS
          const { webkit } = require('playwright');

          (async () => {
            const browser = await webkit.launch();
            const context = await browser.newContext({
              #{storage_opt}
              viewport: { width: #{WIDTH_PT}, height: #{HEIGHT_PT} },
              deviceScaleFactor: #{SCALE},
              userAgent: 'Ruby Native iOS/1.0 Screenshot',
            });
            const page = await context.newPage();

            #{screenshots_js}

            await browser.close();
          })();
        JS
      end
    end
  end
end
