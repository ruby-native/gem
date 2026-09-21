require "ruby_native/cli/check"
require "ruby_native/cli/credentials"
require "ruby_native/cli/deploy"
require "ruby_native/cli/login"
require "ruby_native/cli/mcp"
require "ruby_native/cli/preview"

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
        RubyNative::CLI::Mcp.new(argv).run
      when "logout"
        RubyNative::CLI::Credentials.clear
        puts "Logged out of Ruby Native."
      when "screenshots"
        warn "ruby_native screenshots was removed in 0.9.0."
        warn "Screenshots are now captured by rubynative.com against your deployed site."
        warn "See https://rubynative.com/docs/screenshots for the new flow."
        exit 1
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
      puts "  check         Validate your views against the signal vocabulary"
      puts "    --deployed         Also compare against the build your users have"
      puts "    --paths=A,B        Directories to scan (default: app/views)"
      puts "  deploy        Build every configured platform and wait for it to finish"
      puts "    --ios              Build iOS only"
      puts "    --android          Build Android only"
      puts "    --platform=NAME    Build for ios, android, or all"
      puts "    --if-needed        Skip when this gem version is already built"
      puts "    --skip-check       Deploy without checking your views for broken signals"
      puts "  login         Authenticate with Ruby Native"
      puts "  logout        Remove stored credentials"
      puts "  mcp           Serve the check, signal, and config tools to a coding agent over MCP"
      puts "  preview       Start a tunnel and display a QR code"
      puts "    --port PORT        Rails server port (default: PORT or 3000)"
      puts "    --url URL          Tunnel to this URL instead of localhost"
    end
  end
end
