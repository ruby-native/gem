require "ruby_native/cli/preview"

module RubyNative
  class CLI
    def self.start(argv)
      command = argv.shift
      case command
      when "preview"
        RubyNative::CLI::Preview.new(argv).run
      else
        puts "Usage: ruby_native <command>"
        puts ""
        puts "Commands:"
        puts "  preview    Start a tunnel and display a QR code"
      end
    end
  end
end
