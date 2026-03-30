require "ruby_native/cli/credentials"
require "ruby_native/cli/deploy"
require "ruby_native/cli/login"
require "ruby_native/cli/preview"
require "ruby_native/cli/screenshots"

module RubyNative
  class CLI
    def self.start(argv)
      command = argv.shift
      case command
      when "deploy"
        RubyNative::CLI::Deploy.new(argv).run
      when "preview"
        RubyNative::CLI::Preview.new(argv).run
      when "screenshots"
        RubyNative::CLI::Screenshots.new(argv).run
      when "login"
        RubyNative::CLI::Login.new(argv).run
      when "logout"
        RubyNative::CLI::Credentials.clear
        puts "Logged out of Ruby Native."
      else
        puts "Usage: ruby_native <command>"
        puts ""
        puts "Commands:"
        puts "  deploy        Trigger an iOS build"
        puts "  login         Authenticate with Ruby Native"
        puts "  logout        Remove stored credentials"
        puts "  preview       Start a tunnel and display a QR code"
        puts "  screenshots   Capture web screenshots for App Store images"
      end
    end
  end
end
