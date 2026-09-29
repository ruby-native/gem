require "ruby_native/cli/mcp/prompts"

module RubyNative
  class CLI
    # Prints the `ship` prompt, for an agent whose client cannot show an MCP
    # prompt as a command. Same text, pasted instead of picked.
    class Ship
      def initialize(_argv = [])
      end

      def run
        puts Mcp::Prompts::SHIP
      end
    end
  end
end
