require "ruby_native/cli/check"
require "ruby_native/cli/credentials"
require "ruby_native/cli/deploy"
require "ruby_native/cli/icon"
require "ruby_native/cli/login"
require "ruby_native/cli/mcp"
require "ruby_native/cli/mcp/install"
require "ruby_native/cli/permissions"
require "ruby_native/cli/preview"
require "ruby_native/cli/screenshots"
require "ruby_native/cli/status"
require "ruby_native/cli/testers"

module RubyNative
  class CLI
    def self.start(argv)
      command = argv.shift
      case command
      when "check"
        RubyNative::CLI::Check.new(argv).run
      when "deploy"
        RubyNative::CLI::Deploy.new(argv).run
      when "preview"
        RubyNative::CLI::Preview.new(argv).run
      when "login"
        RubyNative::CLI::Login.new(argv).run
      when "mcp"
        if argv.first == "install"
          RubyNative::CLI::Mcp::Install.new(argv.drop(1)).run
        else
          RubyNative::CLI::Mcp.new(argv).run
        end
      when "status"
        RubyNative::CLI::Status.new(argv).run
      when "logout"
        RubyNative::CLI::Credentials.clear
        puts "Logged out of Ruby Native."
      when "screenshots"
        RubyNative::CLI::Screenshots.new(argv).run
      when "permissions"
        RubyNative::CLI::Permissions.new(argv).run
      when "testers"
        RubyNative::CLI::Testers.new(argv).run
      when "icon"
        RubyNative::CLI::Icon.new(argv).run
      when nil
        print_usage
      else
        puts "Unknown command: #{command}"
        puts ""
        print_usage
        exit 1
      end
    rescue => error
      puts "Something went wrong: #{error.class}: #{error.message}"
      puts "If this keeps happening, report it: https://github.com/ruby-native/gem/issues"
      exit 1
    end

    def self.print_usage
      puts "Usage: ruby_native <command> [options]"
      puts ""
      puts "Commands:"
      puts "  Every command that talks to rubynative.com reads the app from config/ruby_native.yml, or takes --app=ID."
      puts "  check         Validate your views against the signal vocabulary"
      puts "    --deployed         Also compare against the build your users have"
      puts "    --paths=A,B        Directories to scan (default: app/views)"
      puts "  deploy        Build every configured platform and wait for it to finish"
      puts "    --ios              Build iOS only"
      puts "    --android          Build Android only"
      puts "    --platform=NAME    Build for ios, android, or all"
      puts "    --if-needed        Skip when this gem version is already built"
      puts "    --skip-check       Deploy without checking your views for broken signals"
      puts "  icon set PATH Set the app icon, a 1024x1024 PNG (ships with the next deploy)"
      puts "  login         Authenticate with Ruby Native"
      puts "  logout        Remove stored credentials"
      puts "  mcp           Serve the check, signal, config, and status tools to a coding agent over MCP"
      puts "    install            Register the server in .mcp.json for this project"
      puts "  permissions   Show the camera, microphone, and photos permission strings"
      puts "    set NAME TEXT      Set one (ships with the next deploy)"
      puts "  preview       Start a tunnel and display a QR code"
      puts "    --port PORT        Rails server port (default: PORT or 3000)"
      puts "    --url URL          Tunnel to this URL instead of localhost"
      puts "  screenshots   Show the screenshot setup and the latest captures"
      puts "    setup              Generate the key, and set the pages with --paths=/a,/b,/c"
      puts "    capture            Capture App Store screenshots against the deployed site (--android for Play)"
      puts "  status        Where the app is, what is next, and what is in the way"
      puts "  testers       List the TestFlight testers"
      puts "    add EMAIL          Invite a team member to TestFlight"
    end
  end
end
