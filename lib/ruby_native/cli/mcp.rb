require "json"
require "ruby_native/cli/check"
require "ruby_native/cli/mcp/config_validator"
require "ruby_native/cli/mcp/platform"
require "ruby_native/cli/mcp/prompts"
require "ruby_native/cli/credentials"
require "ruby_native/cli/demo_account"
require "ruby_native/cli/icon"
require "ruby_native/cli/listing"
require "ruby_native/cli/permissions"
require "ruby_native/cli/screenshots"
require "ruby_native/cli/link"
require "ruby_native/cli/status"
require "ruby_native/cli/submit"
require "ruby_native/cli/testers"
require "ruby_native/signals"
require "ruby_native/version"

module RubyNative
  class CLI
    # An MCP server over stdin/stdout, so a coding agent working in a Rails app
    # can check its own work before anyone builds it.
    #
    # Signals fail silently by design (see Check): a shell that does not
    # understand one ignores it. A person notices the button that never
    # appeared. An agent writing markup it will never see rendered does not,
    # and neither does the reviewer reading a diff of plausible-looking
    # attributes. These tools hand it the same answers `ruby_native check`
    # gives a person, in a shape it can act on without a device.
    #
    # Read-only throughout, and local by default: check_views, lookup_signals,
    # and validate_config answer from this working copy alone. Three more --
    # config_errors, deployed_builds, and build_status -- read the Ruby Native
    # API with the token `ruby_native login` already stored, because what they
    # answer exists nowhere else: what real devices are failing on, and what
    # the binary in the store is old enough to ignore. Nothing here writes,
    # and nothing deploys -- an agent that can start an App Store build is a
    # different feature with a different set of questions.
    class Mcp
      # The versions of the protocol this speaks. A client asking for one of
      # them gets it back; anything else is answered with the newest, which is
      # what the spec asks a server to do.
      PROTOCOL_VERSIONS = %w[2024-11-05 2025-03-26 2025-06-18].freeze
      PROTOCOL_VERSION = PROTOCOL_VERSIONS.last

      PARSE_ERROR = -32700
      INVALID_REQUEST = -32600
      METHOD_NOT_FOUND = -32601
      INVALID_PARAMS = -32602

      # Raised by a tool that cannot run at all, as opposed to one that ran and
      # found problems. Problems are the answer; these are reported as failures.
      class ToolFailure < StandardError; end

      # A method this server does not implement, which is a different answer
      # from a call it understood and could not carry out.
      class UnknownMethod < StandardError; end

      TOOLS = [
        {
          name: "check_views",
          description: "Check a Rails app's ERB templates against the Ruby Native signal vocabulary and report what " \
                       "the native app will silently ignore: misspelled data-native-* attributes, signals newer than " \
                       "the installed gem, and duplicates of a signal that is only read once. Run this after writing " \
                       "or editing any view that uses data-native-* attributes or native_* helpers -- these failures " \
                       "are invisible at runtime, so nothing else will catch them.",
          inputSchema: {
            type: "object",
            properties: {
              paths: {
                type: "array",
                items: { type: "string" },
                description: "Directories to scan, relative to the app root. Defaults to app/views."
              }
            },
            additionalProperties: false
          },
          annotations: { title: "Check views", readOnlyHint: true, openWorldHint: false }
        },
        {
          name: "lookup_signals",
          description: "Look up the Ruby Native signal vocabulary: every data-native-* attribute the native apps " \
                       "read, the gem version each one needs, and the helper that emits it. Call this before " \
                       "writing a data-native-* attribute rather than guessing at one, because an attribute the " \
                       "apps do not know is ignored without any error.",
          inputSchema: {
            type: "object",
            properties: {
              name: {
                type: "string",
                description: "One signal to look up, with or without the data-native- prefix. Omit to list them all."
              }
            },
            additionalProperties: false
          },
          annotations: { title: "Look up signals", readOnlyHint: true, openWorldHint: false }
        },
        {
          name: "validate_config",
          description: "Check config/ruby_native.yml against what the native apps actually decode. Reports errors " \
                       "that make the app fail to load its config and show an error screen instead of the app -- a " \
                       "tab without an icon, an unrecognized theme -- and warnings for settings that are silently " \
                       "ignored, like a three-digit hex color or a misspelled key. Run this after editing the file.",
          inputSchema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Path to the config file. Defaults to config/ruby_native.yml."
              }
            },
            additionalProperties: false
          },
          annotations: { title: "Validate config", readOnlyHint: true, openWorldHint: false }
        },
        {
          name: "config_errors",
          description: "Report what the app your users are running is failing on: the config errors real devices " \
                       "sent back over the last 48 hours, each with the decode failure that caused it. This is " \
                       "the runtime counterpart to validate_config -- that one says what will fail, this one says " \
                       "what did, on which devices. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: {
                type: "string",
                description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml."
              }
            },
            additionalProperties: false
          },
          annotations: { title: "Config errors from devices", readOnlyHint: true, openWorldHint: true }
        },
        {
          name: "deployed_builds",
          description: "Report the latest iOS and Android build your users can install, and which signals that " \
                       "build is too old to understand. check_views compares your templates against the installed " \
                       "gem; this compares them against the binary in the store, which is where \"the attribute " \
                       "is right but nothing happens on my phone\" usually comes from. Reaches rubynative.com and " \
                       "needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: {
                type: "string",
                description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml."
              }
            },
            additionalProperties: false
          },
          annotations: { title: "Deployed builds", readOnlyHint: true, openWorldHint: true }
        },
        {
          name: "build_status",
          description: "Look up one build by id: whether it succeeded, and the error message if it did not. Use " \
                       "it to follow a build `ruby_native deploy` started. Reaches rubynative.com and needs " \
                       "`ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              build_id: { type: "integer", description: "The build's id, as deploy and this server report it." },
              app_id: {
                type: "string",
                description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml."
              }
            },
            required: [ "build_id" ],
            additionalProperties: false
          },
          annotations: { title: "Build status", readOnlyHint: true, openWorldHint: true }
        },
        {
          name: "link_app",
          description: "Link this project to an app on rubynative.com by writing `ruby_native.app_id` into " \
                       "config/ruby_native.yml. Call it when another tool answers that no app is linked. Without " \
                       "`app_id` it links the account's only app, or lists the apps to choose from. Reaches " \
                       "rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: { type: "string", description: "The app's public id, from the list this tool returns or the dashboard URL." }
            }
          },
          annotations: { title: "Link app", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "status",
          description: "Report where the app is on the way to the App Store and Google Play and what is in the way: " \
                       "setup, subscription, the latest build, store state, and a `blocked_by` list per track for its next act. " \
                       "Each blocker says who clears it. `who: human` means stop and hand the person the steps: " \
                       "paying, creating the app record, or answering a questionnaire Apple gives us no API for. " \
                       "Call this first, and again after the person says they have done a step. Before " \
                       "`ruby_native login` or a linked app it answers from this checkout instead: the config, the " \
                       "first native pass, and what to do next. Otherwise reaches rubynative.com.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: {
                type: "string",
                description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml."
              }
            },
            additionalProperties: false
          },
          annotations: { title: "App status", readOnlyHint: true, openWorldHint: true }
        },
        {
          name: "permissions_set",
          description: "Set the sentence iOS shows when the app first asks for the camera, the microphone, or the " \
                       "photo library. Say what the app does with it, in the user's words. The same three strings decide " \
                       "which permissions the Android manifest declares, so setting one turns the feature on for both " \
                       "stores. They land in Info.plist and the manifest, so a change ships with the next " \
                       "`ruby_native deploy`, not the next Rails deploy. Send only the ones to change; an empty string " \
                       "removes one. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              camera: { type: "string", description: "Why the app uses the camera, for example \"To scan tickets at the door.\"" },
              microphone: { type: "string", description: "Why the app uses the microphone." },
              photos: { type: "string", description: "Why the app reads the photo library." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Set permission strings", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "testers_list",
          description: "List the internal TestFlight testers on the app and whether each has accepted the invite. " \
                       "With platform android, Google Play keeps its list in Play Console, so the answer is the hand-off " \
                       "with the steps. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              platform: { type: "string", enum: [ "ios", "android" ], description: "Defaults to ios." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "List testers", readOnlyHint: true, openWorldHint: true }
        },
        {
          name: "testers_add",
          description: "Invite an App Store Connect team member to TestFlight for this app. Apple emails them the " \
                       "invite; only they can accept it. Someone not on the team is refused with what to do. Reaches " \
                       "rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              email: { type: "string", description: "The Apple ID email the person uses for App Store Connect." },
              platform: { type: "string", enum: [ "ios", "android" ], description: "Defaults to ios." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            required: [ "email" ],
            additionalProperties: false
          },
          annotations: { title: "Add a tester", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "icon_set",
          description: "Upload the app icon: a 1024x1024 PNG with no transparency, from a path in this project. It " \
                       "ships with the next `ruby_native deploy`. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              path: { type: "string", description: "Path to the PNG, relative to the app root." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            required: [ "path" ],
            additionalProperties: false
          },
          annotations: { title: "Set the app icon", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "screenshots_setup",
          description: "Set up App Store screenshots, which rubynative.com captures against the deployed site: " \
                       "generates the screenshot key when the app has none (returned once, with where to put it in " \
                       "the app's Rails credentials and initializer) and sets the 3 to 10 pages to capture. Deploy " \
                       "the site after adding the key, then call screenshots_capture. Reaches rubynative.com and " \
                       "needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              paths: { type: "array", items: { type: "string" }, description: "3 to 10 absolute paths that show the app off, for example [\"/\", \"/inbox\", \"/settings\"]." },
              rotate_key: { type: "boolean", description: "Replace an existing key. The old one stops working." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Set up screenshots", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "screenshots_capture",
          description: "Start a screenshot capture of the deployed site on a phone. Takes about five minutes; follow " \
                       "it with screenshots_list. Publishing the result to the store is a click on the dashboard, not " \
                       "a tool. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              platform: { type: "string", enum: [ "ios", "android" ], description: "Defaults to ios." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Capture screenshots", readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true }
        },
        {
          name: "screenshots_list",
          description: "Report the screenshot setup (key, pages) and the latest capture per platform. Reaches " \
                       "rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "List screenshots", readOnlyHint: true, openWorldHint: true }
        },
        {
          name: "listing_push",
          description: "Save config/ruby_native_listing.yml to Ruby Native as the App Store listing draft. Write the " \
                       "file first: name (30), subtitle (30), keywords (100, comma separated, no spaces), " \
                       "promotional_text (170), description (4000), privacy_policy_url, primary_category and " \
                       "secondary_category from Apple's list. Nothing reaches Apple: a person publishes it. " \
                       "Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Push the listing", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "listing_pull",
          description: "Write config/ruby_native_listing.yml from the listing Ruby Native holds, so a draft made on " \
                       "the dashboard can be edited in the repo. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Pull the listing", readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "demo_account_set",
          description: "Stage the sign-in App Review uses to get past the app's login: an account that exists on " \
                       "the production site. It reaches App Store Connect when the listing is published. Keep it " \
                       "out of the listing file, which is committed. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              name: { type: "string", description: "The username or email the reviewer signs in with." },
              password: { type: "string", description: "Its password." },
              notes: { type: "string", description: "Anything the reviewer needs to know to reach the app's features." },
              required: { type: "boolean", description: "Whether the app needs a sign-in at all. Defaults to true." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            required: [ "name" ],
            additionalProperties: false
          },
          annotations: { title: "Set the demo account", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        },
        {
          name: "submit",
          description: "Submit the app for App Store review, in two calls. Without `confirmation_token` it submits " \
                       "NOTHING: it returns the exact listing, build, and checklist that would go to Apple, as a " \
                       "summary written to be read aloud, plus a token that expires in ten minutes. Show the person " \
                       "that summary and get their explicit yes before calling again with the token. Only then does " \
                       "it submit. Until Apple approves, `withdraw` takes it back out of the queue. With platform " \
                       "android nothing is ever sent: Ruby Native never promotes to production, so the answer is the " \
                       "go-live list with the Play Console promotion steps last. Reaches rubynative.com and needs " \
                       "`ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              confirmation_token: { type: "string", description: "The token from the previous call, after the person said yes." },
              platform: { type: "string", enum: [ "ios", "android" ], description: "Defaults to ios." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Submit for review", readOnlyHint: false, destructiveHint: true, idempotentHint: false, openWorldHint: true }
        },
        {
          name: "withdraw",
          description: "Take the app back out of the App Store review queue. Works from submission until Apple " \
                       "approves it; after release there is nothing to withdraw. Costs a place in the queue and " \
                       "nothing else. Reaches rubynative.com and needs `ruby_native login`.",
          inputSchema: {
            type: "object",
            properties: {
              platform: { type: "string", enum: [ "ios", "android" ], description: "Defaults to ios." },
              app_id: { type: "string", description: "The app's public id. Defaults to ruby_native.app_id in config/ruby_native.yml." }
            },
            additionalProperties: false
          },
          annotations: { title: "Withdraw from review", readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true }
        }
      ].freeze

      # How many inert signals deployed_builds names before it just counts the
      # rest: enough to act on, not so many that the answer is a wall.
      SIGNAL_PREVIEW = 10

      # A raw decode failure can run long. The whole value stays in the
      # structured result; this keeps the readable report readable.
      DETAIL_LIMIT = 400

      # `argv` is accepted so the CLI can build every command the same way; this
      # one takes no flags.
      def initialize(_argv = [], input: $stdin, output: $stdout)
        @input = input
        @output = output
      end

      def run
        @output.sync = true if @output.respond_to?(:sync=)
        warn "ruby_native #{RubyNative::VERSION} MCP server ready on stdio."

        while (line = @input.gets)
          next if line.strip.empty?

          handle(line)
        end
      end

      private

      def handle(line)
        message = JSON.parse(line)
      rescue JSON::ParserError => error
        write(nil, error: failure(PARSE_ERROR, "Invalid JSON: #{error.message}"))
      else
        unless message.is_a?(Hash)
          return write(nil, error: failure(INVALID_REQUEST, "A request has to be a JSON object."))
        end

        id = message["id"]
        # A notification carries no id and takes no reply, not even an error.
        return if id.nil?

        begin
          write(id, result: result_for(message["method"], message["params"] || {}))
        rescue UnknownMethod => error
          write(id, error: failure(METHOD_NOT_FOUND, error.message))
        rescue ToolFailure => error
          write(id, error: failure(INVALID_PARAMS, error.message))
        end
      end

      def result_for(method, params)
        case method
        when "initialize" then initialize_result(params)
        when "tools/list" then { tools: TOOLS }
        when "tools/call" then call(params)
        when "prompts/list" then { prompts: Prompts::LIST }
        when "prompts/get" then prompt(params)
        when "ping" then {}
        else raise UnknownMethod, "Unknown method: #{method.inspect}."
        end
      end

      def initialize_result(params)
        requested = params["protocolVersion"]

        {
          protocolVersion: PROTOCOL_VERSIONS.include?(requested) ? requested : PROTOCOL_VERSION,
          capabilities: { tools: {}, prompts: {} },
          serverInfo: { name: "ruby_native", version: RubyNative::VERSION },
          instructions: INSTRUCTIONS
        }
      end

      def prompt(params)
        name = params["name"]
        Prompts.get(name) or raise ToolFailure, "Unknown prompt: #{name.inspect}. Call prompts/list for the ones this server has."
      end

      # What a client hands the model about this server. "Set up Ruby Native in
      # this app" has to be answerable from here plus the docs, so the setup
      # steps and the rules of the road are stated once, in the handshake.
      INSTRUCTIONS = <<~TEXT.strip
        Ruby Native turns this Rails app into an iOS and Android app. The native shell loads the site
        in web views and reads `data-native-*` attributes (signals) from the HTML to render native
        tabs, buttons, forms, and more. `config/ruby_native.yml` configures the shell and is fetched
        by the app on every launch, so config changes ship with a Rails deploy and need no rebuild.

        Setting up: (1) `config/ruby_native.yml` exists; edit tabs so every path is one the app routes.
        (2) In the layout <head>, add `<%= stylesheet_link_tag :ruby_native %>` and put
        `viewport-fit=cover` in the viewport meta tag. (3) In the layout <body>, add
        `<%= native_tabs_tag %>` and `<%= native_identity_tag(current_user&.id) %>`.
        (4) Run `validate_config` and `check_views`, then `bundle exec ruby_native preview` to see it
        on a phone. Full docs: https://rubynative.com/llms.txt (index) and llms-full.txt (everything).

        Signals fail silently: an attribute the app does not know is ignored with no error anywhere.
        Call `lookup_signals` before writing one and `check_views` after editing any view.

        `status` reports where the app is on the way to the store and a `blocked_by` list. A blocker
        whose `who` is `human` is a step only a person can take (pay, create the App Store Connect
        record, answer a questionnaire Apple has no API for). Stop, show them the steps and the URL,
        and read `status` again when they say it is done. Never claim a `verifiable: false` blocker is
        cleared: only the person can, on the dashboard. Before login or a linked app, `status`
        answers from this checkout and says what comes next.

        The `ship` prompt is the whole way to the stores in one command: install, the first native
        pass, the account, then every store step in order, stopping at the ones only a person can
        take. Start there when asked to ship, set up, or get the app into the stores.
      TEXT

      def call(params)
        name = params["name"]
        arguments = params["arguments"] || {}

        # The protocol owns stdout: one JSON message per line and nothing else.
        # Library code underneath is free to `puts` -- Check does, on the paths
        # this does not take -- so stdout is pointed at stderr for the duration
        # of a call rather than trusted to stay quiet. `@output` holds the real
        # stream, so replies are unaffected.
        quietly do
          case name
          when "check_views" then check_views(arguments)
          when "lookup_signals" then lookup_signals(arguments)
          when "validate_config" then validate_config(arguments)
          when "config_errors" then config_errors(arguments)
          when "deployed_builds" then deployed_builds(arguments)
          when "build_status" then build_status(arguments)
          when "status" then status(arguments)
          when "link_app"
            outcome = Link.link(arguments["app_id"].to_s.strip.empty? ? nil : arguments["app_id"].to_s.strip)
            tool_result(outcome.text, outcome.data, is_error: !outcome.ok)
          when "permissions_set" then with_app(arguments) { |app_id| Permissions.set(app_id, arguments.slice("camera", "microphone", "photos")) }
          when "testers_list" then with_app(arguments) { |app_id| Testers.list(app_id, platform: arguments["platform"] || "ios") }
          when "testers_add" then with_app(arguments) { |app_id| Testers.add(app_id, string!(arguments, "email"), platform: arguments["platform"] || "ios") }
          when "icon_set" then with_app(arguments) { |app_id| Icon.set(app_id, string!(arguments, "path")) }
          when "screenshots_setup" then with_app(arguments) { |app_id| Screenshots.setup(app_id, paths: string_list(arguments["paths"], "paths") || [], rotate_key: arguments["rotate_key"] == true) }
          when "screenshots_capture" then with_app(arguments) { |app_id| Screenshots.capture(app_id, platform: arguments["platform"] || "ios") }
          when "screenshots_list" then with_app(arguments) { |app_id| Screenshots.list(app_id) }
          when "submit"
            with_app(arguments) do |app_id|
              token = arguments["confirmation_token"]
              platform = arguments["platform"] || "ios"
              if platform == "android" || token.to_s.strip.empty?
                Submit.preview(app_id, platform: platform)
              else
                Submit.submit(app_id, token.to_s.strip)
              end
            end
          when "withdraw" then with_app(arguments) { |app_id| Submit.withdraw(app_id, platform: arguments["platform"] || "ios") }
          when "listing_push" then with_app(arguments) { |app_id| Listing.push(app_id) }
          when "listing_pull" then with_app(arguments) { |app_id| Listing.pull(app_id) }
          when "demo_account_set"
            with_app(arguments) do |app_id|
              DemoAccount.set(app_id, name: string!(arguments, "name"), password: arguments["password"], notes: arguments["notes"],
                required: arguments.fetch("required", true) == true)
            end
          else raise ToolFailure, "Unknown tool: #{name.inspect}. Call tools/list for the ones this server has."
          end
        end
      rescue ToolFailure
        raise
      rescue StandardError => error
        # A tool that blew up is an answer the model can work with, so it comes
        # back as a result rather than a protocol error it cannot see.
        tool_result("#{error.class}: #{error.message}", { error: error.message }, is_error: true)
      end

      # --- Tools ---

      def check_views(arguments)
        paths = string_list(arguments["paths"], "paths") || Check::DEFAULT_PATHS

        unless Check.herb_available?
          return tool_result(<<~TEXT.strip, { herb_available: false }, is_error: true)
            check_views needs the herb gem, which parses HTML and ERB together.

            Add it to the Gemfile:
              gem "herb"

            Rails 8.2 and later already ship it as a dependency of Action View.
          TEXT
        end

        files = Check.template_files(paths: paths)
        offenses = Check.signal_offenses(paths: paths) || []

        if files.empty?
          return tool_result("No .html.erb templates found in #{paths.join(", ")}.",
            { paths: paths, checked: 0, offenses: [] })
        end

        errors, warnings = offenses.partition { |offense| offense.severity == :error }

        tool_result(Check.report_lines(files, offenses).join("\n"), {
          paths: paths,
          checked: files.size,
          gem_version: RubyNative::VERSION,
          errors: errors.size,
          warnings: warnings.size,
          offenses: offenses.map do |offense|
            { file: offense.file, line: offense.line, severity: offense.severity.to_s, message: offense.message }
          end
        })
      end

      def lookup_signals(arguments)
        name = arguments["name"]
        return signal_list if name.nil? || name.to_s.strip.empty?

        raise ToolFailure, "`name` has to be a string." unless name.is_a?(String)

        signal_detail(qualify(name.strip))
      end

      def validate_config(arguments)
        path = arguments["path"] || ConfigValidator::DEFAULT_PATH
        raise ToolFailure, "`path` has to be a string." unless path.is_a?(String)

        offenses = in_line_order(ConfigValidator.run(path: path))
        errors, warnings = offenses.partition { |offense| offense.severity == :error }

        tool_result(config_report(path, offenses), {
          path: path,
          errors: errors.size,
          warnings: warnings.size,
          offenses: offenses.map do |offense|
            { file: path, key: offense.key, line: offense.line, severity: offense.severity.to_s, message: offense.message }
          end
        })
      end

      # --- Tools that read the API ---

      def config_errors(arguments)
        app_id = resolve_app_id(arguments)
        return tool_result(Platform::NO_APP_ID, { app_id: nil }, is_error: true) unless app_id

        result = Platform.get("/api/v1/apps/#{app_id}/config_error_reports")
        unless result.ok?
          return tool_result(failure_for(result, app_id), { app_id: app_id }, is_error: true)
        end

        reports = Array(result.value)

        tool_result(config_errors_report(reports), { app_id: app_id, count: reports.size, reports: reports })
      end

      def deployed_builds(arguments)
        app_id = resolve_app_id(arguments)
        return tool_result(Platform::NO_APP_ID, { app_id: nil }, is_error: true) unless app_id

        result = Platform.get("/api/v1/apps/#{app_id}/builds/latest?platform=all")
        return tool_result(failure_for(result, app_id), { app_id: app_id }, is_error: true) unless result.ok?

        builds = result.value.is_a?(Hash) ? result.value : {}

        tool_result(deployed_builds_report(builds), {
          app_id: app_id,
          gem_version: RubyNative::VERSION,
          platforms: builds.transform_values do |state|
            state.is_a?(Hash) ? state.merge("inert_signals" => inert_signals(state["gem_version"])) : state
          end
        })
      end

      def build_status(arguments)
        build_id = arguments["build_id"]
        unless build_id.is_a?(Integer) || build_id.to_s.match?(/\A\d+\z/)
          raise ToolFailure, "`build_id` is required and has to be a number."
        end

        app_id = resolve_app_id(arguments)
        return tool_result(Platform::NO_APP_ID, { app_id: nil }, is_error: true) unless app_id

        result = Platform.get("/api/v1/apps/#{app_id}/builds/#{build_id}")
        unless result.ok?
          # Either half of the path can be the missing one, and the API does
          # not say which.
          message = result.not_found? ? "No build #{build_id} in app #{app_id.inspect} on this account." : result.error
          return tool_result(message, { app_id: app_id, build_id: build_id }, is_error: true)
        end

        build = result.value.is_a?(Hash) ? result.value : {}

        tool_result(build_status_report(build), build.merge("app_id" => app_id))
      end

      # Before there is anything to fetch, the answer is what this checkout
      # shows: the same report `ruby_native status` prints, so the first thing
      # an agent asks has an answer even on a fresh clone with no account.
      def status(arguments)
        app_id = resolve_app_id(arguments)
        if app_id.nil? || Credentials.token.nil?
          local = Status.local
          return tool_result(Status.local_report(local), local)
        end

        result = Status.fetch(app_id)
        unless result.ok?
          return tool_result(Status.failure_message(result, app_id), { app_id: app_id }, is_error: true)
        end

        status = result.value.is_a?(Hash) ? result.value : {}

        tool_result(Status.report(status), status)
      end

      # The CLI commands do the work; a tool is the same verb answered in the
      # protocol's shape.
      def with_app(arguments)
        app_id = resolve_app_id(arguments)
        return tool_result(Platform::NO_APP_ID, { app_id: nil }, is_error: true) unless app_id

        outcome = yield(app_id)
        tool_result(outcome.text, outcome.data, is_error: !outcome.ok)
      end

      def string!(arguments, name)
        value = arguments[name]
        raise ToolFailure, "`#{name}` is required and has to be a string." unless value.is_a?(String) && !value.strip.empty?

        value.strip
      end

      # --- Rendering ---

      def config_errors_report(reports)
        if reports.empty?
          return "No config errors reported in the last 48 hours. Only a device running a build reports here, so " \
                 "this says nothing about config you have not deployed yet."
        end

        lines = [ "#{reports.size} config #{reports.size == 1 ? "error" : "errors"} reported by devices in the " \
                  "last 48 hours, newest first.", "" ]

        reports.each do |report|
          lines << "#{report["error_type"]} — #{report["headline"]}"
          lines << "  #{report["error_description"]}" unless report["error_description"].to_s.strip.empty?
          lines << "  #{devices_line(report)}"
          lines << "  first seen #{report["first_seen_at"]}, last seen #{report["last_seen_at"]}"

          detail = report["error_detail"].to_s.strip
          lines << "  #{truncate(detail, DETAIL_LIMIT).gsub("\n", "\n  ")}" unless detail.empty?
          lines << ""
        end

        lines.join("\n").strip
      end

      def devices_line(report)
        os = [ report["os_name"], report["os_version"] ].map(&:to_s).reject(&:empty?).join(" ")
        version = report["app_version"].to_s
        build = report["build_number"].to_s
        app = build.empty? ? version : "#{version} (#{build})".strip

        [ os, report["device_model"].to_s, app.empty? ? "" : "app #{app}" ].reject(&:empty?).join(" · ")
      end

      def deployed_builds_report(builds)
        return "#{Platform::HOST} has no build information for this app." if builds.empty?

        lines = [ "This project is on ruby_native #{RubyNative::VERSION}.", "" ]

        builds.each do |platform, state|
          label = platform == "ios" ? "iOS" : platform.to_s.capitalize

          unless state.is_a?(Hash)
            lines << "#{label} — no information."
            next
          end

          unless state["deployable"]
            lines << "#{label} — not set up for deploys yet."
            next
          end

          built = state["gem_version"]
          if built.to_s.empty?
            lines << "#{label} — set up to deploy, but nothing has been built yet."
            next
          end

          lines << "#{label} — build #{state["number"]} (#{state["version"]}), #{state["status"]}, " \
                   "made with ruby_native #{built}."
          lines.concat(skew_lines(built))
        end

        lines.join("\n").strip
      end

      # The point of the whole tool: a signal the shipped binary predates is
      # inert on the phone in someone's hand, and says nothing about it there
      # or anywhere else.
      def skew_lines(built)
        inert = inert_signals(built)
        return [ "  Nothing in the signal vocabulary is newer than that build." ] if inert.empty?

        shown = inert.first(SIGNAL_PREVIEW)
        listed = shown.join(", ")
        remaining = inert.size - shown.size
        listed += ", and #{remaining} more" if remaining.positive?

        [
          "  #{inert.size} #{inert.size == 1 ? "signal is" : "signals are"} newer than that build, so they do " \
          "nothing on the app your users have, with no error anywhere: #{listed}.",
          "  Deploy on #{RubyNative::VERSION} to use them."
        ]
      end

      def inert_signals(built)
        return [] if built.to_s.empty?

        deployed = Gem::Version.new(built.to_s.delete_prefix("v"))

        Signals.names.select do |name|
          since = Signals.since(name)
          since && Gem::Version.new(since) > deployed
        end
      rescue ArgumentError
        # gem_version reaches the API as unvalidated CLI input, so it may not
        # be a version at all. No comparison beats a wrong one.
        []
      end

      def build_status_report(build)
        return "No build information came back." if build.empty?

        label = build["platform"] == "ios" ? "iOS" : build["platform"].to_s.capitalize
        lines = [ "#{label} build #{build["number"]} (#{build["version"]}) — #{build["status"]}." ]

        if build["gem_version"].to_s != ""
          lines << "Made with ruby_native #{build["gem_version"]} on Ruby Native #{build["native_version"]}."
        end
        lines << "Error: #{build["error_message"]}" unless build["error_message"].to_s.strip.empty?
        lines << build["notice"] unless build["notice"].to_s.strip.empty?

        lines.join("\n")
      end


      def signal_list
        rows = Signals.names.map do |name|
          { name: name, since: Signals.since(name), helper: Signals.helper(name), singleton: Signals.singleton?(name) }
        end

        width = Signals.names.map(&:length).max
        lines = rows.map do |row|
          "#{row[:name].ljust(width)}  #{(row[:since] || "-").ljust(8)}#{row[:helper]}".rstrip
        end

        text = <<~TEXT.strip
          #{Signals.names.size} signals, as of ruby_native #{RubyNative::VERSION}. Columns: signal, the gem version
          that introduced it, the helper that emits it. A signal needing a version newer than the app's build is
          ignored on device without an error. Signals with no version are written by the app, not by your views.

          #{lines.join("\n")}

          What each one does: https://rubynative.com/docs
        TEXT

        tool_result(text, { count: rows.size, gem_version: RubyNative::VERSION, signals: rows })
      end

      def signal_detail(name)
        unless Signals.known?(name)
          suggestion = Signals.nearest(name)
          text = "`#{name}` is not a Ruby Native signal, so the apps ignore it."
          text += " Did you mean `#{suggestion}`?" if suggestion

          return tool_result(text, { name: name, known: false, suggestion: suggestion })
        end

        since = Signals.since(name)
        supported = since.nil? || Gem::Version.new(RubyNative::VERSION) >= Gem::Version.new(since)

        details = []
        details << (since ? "Needs ruby_native #{since}." : "Written by the app, not by your views.")
        details << "Emitted by `#{Signals.helper(name)}`." if Signals.helper(name)
        details << "Read once per page: a second element carrying it is ignored." if Signals.singleton?(name)
        details << "This app is on #{RubyNative::VERSION}, so it is inert here until the gem is updated." unless supported

        tool_result("`#{name}` — #{details.join(" ")}", {
          name: name,
          known: true,
          since: since,
          helper: Signals.helper(name),
          singleton: Signals.singleton?(name),
          gem_version: RubyNative::VERSION,
          supported: supported
        })
      end

      # Reading order, so a reader works down the file. Offenses the validator
      # could not pin to a line go last rather than to the top.
      def in_line_order(offenses)
        offenses.each_with_index.sort_by { |offense, index| [offense.line || Float::INFINITY, index] }.map(&:first)
      end

      def config_report(path, offenses)
        return "Checked #{path}. No problems found." if offenses.empty?

        errors, warnings = offenses.partition { |offense| offense.severity == :error }

        lines = [path]
        offenses.each do |offense|
          location = "#{offense.line}:".ljust(5)
          location = " " * 5 unless offense.line
          lines << "  #{location}#{offense.severity.to_s.ljust(8)}#{offense.message}"
        end
        lines << ""
        lines << "#{errors.size} #{errors.size == 1 ? "error" : "errors"}, " \
                 "#{warnings.size} #{warnings.size == 1 ? "warning" : "warnings"}."

        lines.join("\n")
      end

      # --- Protocol ---

      def tool_result(text, structured = nil, is_error: false)
        result = { content: [{ type: "text", text: text }], isError: is_error }
        result[:structuredContent] = structured if structured
        result
      end

      def failure(code, message)
        { code: code, message: message }
      end

      def write(id, body)
        @output.puts(JSON.generate({ jsonrpc: "2.0", id: id }.merge(body)))
      end

      def quietly
        original = $stdout
        $stdout = $stderr
        yield
      ensure
        $stdout = original
      end

      # Every app-scoped route answers 404 the same way for an app the token
      # cannot see, which is the only 404 these tools can provoke.
      def failure_for(result, app_id)
        return result.error unless result.not_found?

        "No app #{app_id.inspect} on this account. Check `ruby_native.app_id` in #{Platform::CONFIG_PATH}, " \
          "or pass `app_id`."
      end

      def resolve_app_id(arguments)
        app_id = arguments["app_id"]
        raise ToolFailure, "`app_id` has to be a string." unless app_id.nil? || app_id.is_a?(String)

        app_id = Platform.app_id if app_id.to_s.strip.empty?
        app_id.to_s.strip.empty? ? nil : app_id
      end

      def truncate(text, limit)
        text.length > limit ? "#{text[0, limit].rstrip}…" : text
      end

      def string_list(value, name)
        return nil if value.nil?
        raise ToolFailure, "`#{name}` has to be a list of strings." unless value.is_a?(Array) && value.all?(String)

        entries = value.map(&:strip).reject(&:empty?)
        entries.empty? ? nil : entries
      end

      # Agents reach for the bare name as often as the attribute, and both mean
      # the same thing here. A name that is already prefixed is left alone, so a
      # typo still gets its "did you mean".
      def qualify(name)
        name.start_with?("data-native-") ? name : "data-native-#{name.delete_prefix("data-")}"
      end
    end
  end
end
