require "ruby_native/cli/command"

module RubyNative
  class CLI
    # The app icon: a 1024x1024 PNG with no transparency. It goes in the asset
    # catalog, so a new one ships with the next build.
    class Icon < Command
      def run
        ensure_authenticated!
        app_id = app_id!

        unless positional.first == "set" && positional[1]
          puts "Usage: ruby_native icon set <path/to/icon.png>"
          exit 1
        end
        finish(self.class.set(app_id, positional[1]))
      end

      def self.set(app_id, path)
        return Outcome.new(ok: false, text: "No file at #{path}.", data: {}) unless File.file?(path)

        result = Mcp::Platform.put_file("/api/v1/apps/#{app_id}/icon", field: "icon", file: path, content_type: "image/png")
        return failure(result) unless result.ok?

        success("Icon set from #{path}. #{result.value["note"]}", result.value)
      end
    end
  end
end
