module RubyNative
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a Ruby Native config file at config/ruby_native.yml"

      # The tab bar only appears with two or more tabs (the shell hides it
      # otherwise), and a tab pointing at a path the app does not route 404s
      # on first launch. Both failures land in the first five minutes, so tabs
      # come from the app's own routes, and only from routes that exist.
      MAX_TABS = 4

      # Route segments that are never a tab: auth, framework, and Ruby Native's
      # own mounts.
      SKIPPED_SEGMENTS = %w[
        rails up cable native assets manifest service-worker pwa admin api webhooks
        session sessions sign_in sign_up signin signup login logout password passwords
        registration registrations users auth oauth
      ].freeze

      TAB_ICONS = {
        "" => "house",
        "home" => "house",
        "dashboard" => "house",
        "profile" => "person",
        "account" => "person",
        "me" => "person",
        "settings" => "gear",
        "preferences" => "gear",
        "inbox" => "envelope",
        "messages" => "envelope",
        "notifications" => "bell",
        "search" => "magnifyingglass",
        "calendar" => "calendar",
        "events" => "calendar",
        "orders" => "shippingbox",
        "favorites" => "star",
        "bookmarks" => "star"
      }.freeze

      DEFAULT_ICON = "list.bullet".freeze

      def copy_config
        @tabs = proposed_tabs
        template "ruby_native.yml", "config/ruby_native.yml"
      end

      def add_allowed_host
        host_line = %(  config.hosts << ".trycloudflare.com" if config.hosts.is_a?(Array)\n)
        dev_config = "config/environments/development.rb"

        return unless File.exist?(File.join(destination_root, dev_config))
        contents = File.read(File.join(destination_root, dev_config))
        return if contents.include?("trycloudflare")

        # Match any configure block, not just Rails.application.configure; some
        # apps use MyApp::Application.configure and Thor's environment helper
        # silently skips those.
        configure_block = /^[\w:.]+\.configure do\s*\n/
        if contents.match?(configure_block)
          inject_into_file dev_config, host_line, after: configure_block, verbose: false
          say "  Added .trycloudflare.com to allowed hosts in development.rb", :green
        else
          say "  Couldn't find a configure block in development.rb. Add this line inside it:", :yellow
          say "  #{host_line.strip}", :yellow
        end
      end

      def add_gitignore
        gitignore = File.join(destination_root, ".gitignore")
        return unless File.exist?(gitignore)
        return if File.read(gitignore).include?(".ruby_native")

        append_to_file ".gitignore", "\n# Ruby Native\n.ruby_native/\n"
        say "  Added .ruby_native/ to .gitignore", :green
      end

      def print_next_steps
        say ""
        say "Ruby Native installed.", :green
        say ""
        say "  Tabs, from your routes: #{@tabs.map { |tab| "#{tab[:path]} (#{tab[:title]})" }.join(", ")}"
        if @tabs.size < 2
          say "  The tab bar stays hidden until config/ruby_native.yml has a second tab.", :yellow
        else
          say "  Change them in config/ruby_native.yml."
        end
        say ""
        say "By hand:"
        say "  1. Add <%= stylesheet_link_tag :ruby_native %> to your layout <head>"
        say "  2. Add viewport-fit=cover to your viewport meta tag"
        say "  3. Add <%= native_tabs_tag %> and <%= native_identity_tag(current_user&.id) %> to your layout <body>"
        say "  4. Preview on your phone: bundle exec ruby_native preview"
        say ""
        say "  Docs: https://rubynative.com/docs"
        say "  Agents: https://rubynative.com/llms.txt for a docs index, llms-full.txt for all of it as plain text"
        say ""
        say "Or hand it to your agent:", :green
        say ""
        say "    bundle exec ruby_native mcp install"
        say ""
        say "Then, in your agent: /mcp__ruby-native__ship"
        say ""
      end

      private

      def proposed_tabs
        paths = routable_paths
        paths = [ "/" ] if paths.empty?

        paths.first(MAX_TABS).map do |path|
          segment = path.delete_prefix("/")
          { title: title_for(segment), path: path, icon: TAB_ICONS.fetch(segment, DEFAULT_ICON) }
        end
      end

      # Routes a library draws into the app for its own use. Turbo's
      # historical-location routes and the PWA manifest are GET, static, and
      # one segment, so without this a fresh app's tabs were three Turbo
      # internals.
      LIBRARY_CONTROLLERS = %r{\A(turbo|rails|active_storage|action_mailbox|action_cable|action_text)/}

      # Static, single-segment GET routes, root first, in the order the routes
      # file declares them. Anything with a parameter, a glob, or a second
      # segment is a page you reach from a tab, not a tab.
      def routable_paths
        paths = Rails.application.routes.routes.filter_map do |route|
          next if route.respond_to?(:internal) && route.internal
          next unless route.verb.to_s.match?(/\bGET\b/)
          next if route.defaults[:controller].to_s.match?(LIBRARY_CONTROLLERS)

          path = route.path.spec.to_s.sub(/\(\.:format\)\z/, "")
          next unless path.start_with?("/")
          next if path.match?(/[:*]/)

          segments = path.delete_prefix("/").split("/")
          next if segments.size > 1
          next if SKIPPED_SEGMENTS.include?(segments.first)

          path
        end.uniq

        paths.partition { |path| path == "/" }.flatten
      rescue StandardError
        []
      end

      def title_for(segment)
        return "Home" if segment.empty?

        segment.tr("_-", "  ").split.map(&:capitalize).join(" ")
      end
    end
  end
end
