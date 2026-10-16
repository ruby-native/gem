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

      # Without a camera sentence the build has no NSCameraUsageDescription, so the
      # native scanner refuses and a scan button does nothing. Returns where the
      # views scan when the app has none; nil when it's fine or can't be told.
      def self.scan_without_camera(app_id, paths: [ "app/views" ])
        use = paths.flat_map { |path| Dir.glob(File.join(path, "**", "*.erb")) }.sort.lazy.filter_map do |file|
          line = File.foreach(file).with_index(1).find { |text, _| text.include?("native_scan_button_tag") }&.last
          [ file, line ] if line
        end.first
        return nil unless use

        result = Mcp::Platform.get("/api/v1/apps/#{app_id}/permissions")
        return nil unless result.ok?

        camera = result.value.is_a?(Hash) ? result.value.dig("permissions", "camera") : nil
        camera.to_s.strip.empty? ? use : nil
      end

      def self.scan_without_camera_message(file, line)
        "#{file}:#{line} uses native_scan_button_tag, but the app has no camera sentence, so Scan won't open. " \
          "Add one with `bundle exec ruby_native permissions set camera \"Why the app uses the camera\"`; it ships with the next deploy."
      end

      def self.render(value)
        permissions = value.is_a?(Hash) ? value["permissions"] || {} : {}
        NAMES.map { |name| "#{name.ljust(11)} #{permissions[name].to_s.empty? ? "(not set, the app cannot ask)" : permissions[name]}" }.join("\n")
      end
    end
  end
end
