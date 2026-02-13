module RubyNative
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a Ruby Native config file at config/ruby_native.yml"

      def copy_config
        template "ruby_native.yml", "config/ruby_native.yml"
      end

      def add_allowed_host
        host_line = '  config.hosts << ".trycloudflare.com"'
        dev_config = "config/environments/development.rb"

        return unless File.exist?(File.join(destination_root, dev_config))
        return if File.read(File.join(destination_root, dev_config)).include?("trycloudflare")

        environment(host_line, env: "development")
        say "  Added .trycloudflare.com to allowed hosts in development.rb", :green
      end

      def copy_claude_instructions
        return unless File.directory?(File.join(destination_root, ".claude"))
        template "CLAUDE.md", ".claude/ruby_native.md"
      end

      def print_next_steps
        say ""
        say "Ruby Native installed! Next steps:", :green
        say ""
        say "  1. Edit config/ruby_native.yml with your app name, colors, and tabs"
        say "  2. Add to your layout <head>:"
        say "       <%= stylesheet_link_tag :ruby_native %>"
        say "  3. Add to your layout <body>:"
        say "       <%= native_tabs_tag %>"
        say "  4. Preview on your device:"
        say "       ruby_native preview"
        say ""
        if File.directory?(File.join(destination_root, ".claude"))
          say "  Tip: .claude/ruby_native.md was added with setup instructions."
          say "  Open Claude Code and ask \"what do I need to do next?\" for guided help."
          say ""
        end
      end
    end
  end
end
