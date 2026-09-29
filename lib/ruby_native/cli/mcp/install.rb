require "json"

module RubyNative
  class CLI
    class Mcp
      # Registers the server in the project's `.mcp.json`, the file Claude Code
      # reads for project-scoped servers, so "point your agent at it" is one
      # command rather than a JSON snippet to paste. Anything already in the
      # file is kept; only the ruby-native entry is written.
      class Install
        PATH = ".mcp.json".freeze
        NAME = "ruby-native".freeze
        SERVER = { "command" => "bundle", "args" => %w[exec ruby_native mcp] }.freeze

        def initialize(_argv = [])
        end

        def run
          config = existing_config
          servers = config["mcpServers"] = config.fetch("mcpServers", {})
          already = servers[NAME] == SERVER
          servers[NAME] = SERVER

          File.write(PATH, JSON.pretty_generate(config) + "\n") unless already

          puts already ? "#{PATH} already has the ruby-native server." : "Added the ruby-native server to #{PATH}."
          puts "Claude Code picks it up on its next start in this directory."
          puts ""
          puts "Other clients take the same entry:"
          puts JSON.pretty_generate("mcpServers" => { NAME => SERVER })
          puts ""
          puts "Then, in your agent:"
          puts ""
          puts "    /mcp__#{NAME}__ship"
          puts ""
          puts "It walks every step to the App Store and Google Play and stops at the ones only you can take."
          puts "No prompt support in your agent? Paste the output of: bundle exec ruby_native ship"
        end

        private

        def existing_config
          return {} unless File.exist?(PATH)

          config = JSON.parse(File.read(PATH))
          config.is_a?(Hash) ? config : {}
        rescue JSON::ParserError
          puts "#{PATH} is not valid JSON, so nothing was written. Fix or remove it and run this again."
          exit 1
        end
      end
    end
  end
end
