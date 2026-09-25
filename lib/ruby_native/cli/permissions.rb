require "ruby_native/cli/command"

module RubyNative
  class CLI
    # The strings iOS shows when the app first asks for the camera, the
    # microphone, or the photo library. They land in Info.plist, so a change
    # ships with the next build.
    class Permissions < Command
      NAMES = %w[camera microphone photos].freeze

      def run
        ensure_authenticated!
        app_id = app_id!

        case positional.first
        when "set"
          name, text = positional[1], positional[2]
          unless NAMES.include?(name) && text
            puts "Usage: ruby_native permissions set <#{NAMES.join("|")}> \"<why the app asks>\""
            exit 1
          end
          finish(self.class.set(app_id, name => text))
        when "list", nil
          finish(self.class.list(app_id))
        else
          puts "Unknown permissions command #{positional.first.inspect}. Use `set` or `list`."
          exit 1
        end
      end

      def self.list(app_id)
        result = Mcp::Platform.get("/api/v1/apps/#{app_id}/permissions")
        return failure(result) unless result.ok?

        success(render(result.value), result.value)
      end

      def self.set(app_id, permissions)
        unknown = permissions.keys.map(&:to_s) - NAMES
        return Outcome.new(ok: false, text: "Unknown permission #{unknown.first.inspect}. Use #{NAMES.join(", ")}.", data: {}) if unknown.any?

        result = Mcp::Platform.patch("/api/v1/apps/#{app_id}/permissions", { permissions: permissions })
        return failure(result) unless result.ok?

        changed = Array(result.value["changed"])
        lines = [ render(result.value) ]
        lines << ""
        lines << (changed.empty? ? "Nothing changed." : "Changed: #{changed.join(", ")}. #{result.value["note"]}")
        success(lines.join("\n"), result.value)
      end

      def self.render(value)
        permissions = value.is_a?(Hash) ? value["permissions"] || {} : {}
        NAMES.map { |name| "#{name.ljust(11)} #{permissions[name].to_s.empty? ? "(not set, the app cannot ask)" : permissions[name]}" }.join("\n")
      end
    end
  end
end
