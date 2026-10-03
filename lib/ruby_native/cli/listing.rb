require "erb"
require "yaml"
require "ruby_native/cli/command"

module RubyNative
  class CLI
    # The App Store listing, written in config/ruby_native_listing.yml and
    # staged with rubynative.com. `push` stops there. `publish` is a different
    # verb on purpose: the agent prompt names `push`, so following it can never
    # put words on the store, and someone shipping from a terminal types the
    # same act as pressing the button.
    class Listing < Command
      PATH = "config/ruby_native_listing.yml".freeze
      FIELDS = %w[name subtitle primary_category secondary_category keywords promotional_text privacy_policy_url copyright description].freeze
      CONTACT_FIELDS = %w[first_name last_name email phone].freeze
      LIMITS = { "name" => 30, "subtitle" => 30, "keywords" => 100, "promotional_text" => 170, "description" => 4000 }.freeze

      def run
        ensure_authenticated!
        app_id = app_id!

        case positional.first
        when "push" then finish(self.class.push(app_id))
        when "pull" then finish(self.class.pull(app_id))
        when "publish" then finish(self.class.publish(app_id, platform: @argv.include?("--android") ? "android" : "ios"))
        else
          puts "Usage: ruby_native listing <push|pull|publish> [--android]"
          puts "  push       Save #{PATH} to Ruby Native. Nothing reaches a store."
          puts "  pull       Write #{PATH} from what Ruby Native holds."
          puts "  publish    Push, then send the listing to App Store Connect."
          puts "  --android  Send the title and descriptions to the Google Play listing instead."
          exit 1
        end
      end

      def self.push(app_id)
        listing = read_file
        return listing if listing.is_a?(Outcome)

        problems = over_limits(listing)
        return Outcome.new(ok: false, text: (["#{PATH} has fields over Apple's limits:"] + problems).join("\n"), data: { "errors" => problems }) if problems.any?

        contact = listing.delete("review_contact")
        body = { listing: listing }
        body[:review_contact] = contact if contact&.any?
        result = Mcp::Platform.patch("/api/v1/apps/#{app_id}/listing", body)
        return failure(result) unless result.ok?

        changed = Array(result.value["changed"])
        lines = [ changed.empty? ? "Nothing changed." : "Saved #{changed.join(", ")}." ]
        missing = Array(result.value["missing"])
        lines << "Still missing before it can be submitted: #{missing.join(", ")}." if missing.any?
        lines << "Nothing has reached Apple. `ruby_native listing publish` sends it, or publish from the dashboard."
        success(lines.join("\n"), result.value)
      end

      def self.pull(app_id)
        result = Mcp::Platform.get("/api/v1/apps/#{app_id}/listing")
        return failure(result) unless result.ok?

        listing = (result.value["listing"] || {}).merge("review_contact" => result.value["review_contact"] || {})
        File.write(PATH, render(listing))
        success("Wrote #{PATH} from the listing Ruby Native holds.", result.value)
      end

      def self.publish(app_id, platform: "ios")
        pushed = push(app_id)
        return pushed unless pushed.ok

        result = Mcp::Platform.post("/api/v1/apps/#{app_id}/listing/publish", platform == "android" ? { platform: "android" } : nil)
        return failure(result) unless result.ok?

        success(result.value["note"].to_s, result.value)
      end

      # ERB first so a description can interpolate, then YAML. Only known
      # keys go up; anything else in the file is left alone and reported.
      def self.read_file
        return Outcome.new(ok: false, text: "No #{PATH}. Run `ruby_native listing pull` to start one from the dashboard's draft, or write it by hand.", data: {}) unless File.exist?(PATH)

        data = YAML.safe_load(ERB.new(File.read(PATH, encoding: "UTF-8")).result, aliases: true)
        return Outcome.new(ok: false, text: "#{PATH} has to be a YAML mapping of listing fields.", data: {}) unless data.is_a?(Hash)

        # An empty line from the template is a field not written yet, not a
        # request to blank it.
        listing = data.slice(*FIELDS).compact.transform_values { |value| value.to_s.strip }
        contact = data["review_contact"]
        listing["review_contact"] = contact.slice(*CONTACT_FIELDS).compact.transform_values { |value| value.to_s.strip } if contact.is_a?(Hash)
        listing
      rescue Psych::SyntaxError => error
        Outcome.new(ok: false, text: "#{PATH} is not valid YAML: #{error.message}", data: {})
      end

      def self.over_limits(listing)
        LIMITS.filter_map do |field, limit|
          length = listing[field].to_s.length
          "  #{field} is #{length} characters, the limit is #{limit}" if length > limit
        end
      end

      # Every field is written, empty ones with their limit, so a pull on an
      # app with no listing yet is a template rather than a file of comments
      # that push then refuses.
      def self.render(listing)
        lines = [ "# App Store listing. `ruby_native listing push` saves it to Ruby Native;", "# publishing to App Store Connect is a separate step.", "" ]
        FIELDS.each do |field|
          lines.concat(render_contact(listing["review_contact"] || {})) if field == "description"
          value = listing[field]
          if value.nil? || value.to_s.empty?
            lines << "#{field}:#{" # up to #{LIMITS[field]} characters" if LIMITS[field]}"
            next
          end

          if field == "description"
            lines << "description: |-"
            value.to_s.each_line { |line| lines << "  #{line.rstrip}" }
          else
            lines << "#{field}: #{scalar(value)}"
          end
        end
        lines.join("\n") + "\n"
      end

      def self.render_contact(contact)
        lines = [ "review_contact: # who App Review contacts; never shown on the store" ]
        CONTACT_FIELDS.each do |field|
          value = contact[field]
          lines << if value.nil? || value.to_s.empty?
            "  #{field}:#{" # \"+1 503 555 0100\", quoted" if field == "phone"}"
          else
            "  #{field}: #{scalar(value)}"
          end
        end
        lines
      end

      # YAML reads an unquoted +15035550100 as a number and drops the +.
      def self.scalar(value)
        value.to_s.include?(":") || value.to_s.start_with?("#", "+") ? value.to_s.inspect : value
      end
    end
  end
end
