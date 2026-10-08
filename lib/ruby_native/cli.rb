require "ruby_native/cli/apple"
require "ruby_native/cli/check"
require "ruby_native/cli/credentials"
require "ruby_native/cli/demo_account"
require "ruby_native/cli/deploy"
require "ruby_native/cli/icon"
require "ruby_native/cli/link"
require "ruby_native/cli/listing"
require "ruby_native/cli/login"
require "ruby_native/cli/mcp"
require "ruby_native/cli/mcp/install"
require "ruby_native/cli/permissions"
require "ruby_native/cli/preview"
require "ruby_native/cli/screenshots"
require "ruby_native/cli/ship"
require "ruby_native/cli/status"
require "ruby_native/cli/submit"
require "ruby_native/cli/testers"

module RubyNative
  class CLI
    def self.start(argv)
      command = argv.shift
      case command
      when "apple"
        RubyNative::CLI::Apple.new(argv).run
      when "check"
        RubyNative::CLI::Check.new(argv).run
      when "deploy"
        RubyNative::CLI::Deploy.new(argv).run
      when "preview"
        RubyNative::CLI::Preview.new(argv).run
      when "login"
        RubyNative::CLI::Login.new(argv).run
      when "mcp"
        if argv.first == "install"
          RubyNative::CLI::Mcp::Install.new(argv.drop(1)).run
        else
          RubyNative::CLI::Mcp.new(argv).run
        end
      when "status"
        RubyNative::CLI::Status.new(argv).run
      when "ship"
        RubyNative::CLI::Ship.new(argv).run
      when "link"
        RubyNative::CLI::Link.new(argv).run
      when "submit"
        RubyNative::CLI::Submit.new(argv).run
      when "withdraw"
        RubyNative::CLI::Withdraw.new(argv).run
      when "logout"
        RubyNative::CLI::Credentials.clear
        puts "Logged out of Ruby Native."
      when "screenshots"
        RubyNative::CLI::Screenshots.new(argv).run
      when "permissions"
        RubyNative::CLI::Permissions.new(argv).run
      when "testers"
        RubyNative::CLI::Testers.new(argv).run
      when "icon"
        RubyNative::CLI::Icon.new(argv).run
      when "listing"
        RubyNative::CLI::Listing.new(argv).run
      when "demo_account"
        RubyNative::CLI::DemoAccount.new(argv).run
      when nil
        print_usage
      else
        puts "Unknown command: #{command}"
        puts ""
        print_usage
        exit 1
      end
    rescue => error
      puts "Something went wrong: #{error.class}: #{error.message}"
      puts "If this keeps happening, report it: https://github.com/ruby-native/gem/issues"
      exit 1
    end

    def self.print_usage
      puts "Usage: ruby_native <command> [options]"
      puts ""
      puts "Commands:"
      puts "  Every command that talks to rubynative.com reads the app from config/ruby_native.yml, or takes --app=ID."
      puts "  link [APP_ID]  Link this project to an app on your account (writes ruby_native.app_id)"
      puts "  apple key PATH --key-id=KEY --issuer-id=ISSUER --team-id=TEAM"
      puts "                Hand over the App Store Connect key (.p8) and wait for Apple to accept it"
      puts "  check         Validate your views against the signal vocabulary"
      puts "    --deployed         Also compare against the build your users have"
      puts "    --paths=A,B        Directories to scan (default: app/views)"
      puts "  demo_account  set --name=EMAIL --password=SECRET  Stage the reviewer's sign-in"
      puts "  deploy        Build every configured platform and wait for it to finish"
      puts "    --ios              Build iOS only"
      puts "    --android          Build Android only"
      puts "    --platform=NAME    Build for ios, android, or all"
      puts "    --if-needed        Skip when this gem version is already built"
      puts "    --version=1.1      The App Store version to build (default: the next patch once live)"
      puts "    --skip-check       Deploy without checking your views for broken signals"
      puts "  icon set PATH Set the app icon, a 1024x1024 PNG (ships with the next deploy)"
      puts "  listing       push, pull, or publish the store listing in config/ruby_native_listing.yml"
      puts "    publish            Send it to every store the app has started (--ios or --android for one)"
      puts "  login         Authenticate with Ruby Native"
      puts "  logout        Remove stored credentials"
      puts "  mcp           Serve the check, signal, config, and status tools to a coding agent over MCP"
      puts "    install            Register the server in .mcp.json for this project"
      puts "  permissions   Show the camera, microphone, and photos permission strings"
      puts "    set NAME TEXT      Set one (ships with the next deploy)"
      puts "  preview       Start a tunnel and display a QR code"
      puts "    --port PORT        Rails server port (default: PORT or 3000)"
      puts "    --url URL          Tunnel to this URL instead of localhost"
      puts "  screenshots   Show the screenshot setup and the latest captures"
      puts "    setup              Set the pages with --paths=/a,/b,/c for every started store (--ios or --android for one)"
      puts "    --sign-in          The pages need a signed-in user: generate the screenshot key"
      puts "    capture            Capture screenshots against the deployed site for every started store (--ios or --android for one)"
      puts "  ship          Print the prompt that walks an agent to the App Store and Google Play (the MCP server has it as /mcp__ruby-native__ship)"
      puts "  status        Where the app is, what is next, and what is in the way. Works before login, from this checkout"
      puts "  submit        Show exactly what would go to App Store review, then ask before sending it"
      puts "    --yes              Skip the question"
      puts "    --confirm=NAME     Say a questionnaire is done: app_privacy, age_rating, or play_content"
      puts "    --ios              The App Store only"
      puts "    --android          Only what stands between the app and Google Play, and the promotion steps"
      puts "  testers       List the testers for every started store"
      puts "    add EMAIL          Invite a team member to TestFlight (Play keeps its list in Play Console)"
      puts "    --ios, --android   One store only"
      puts "  withdraw      Take the app back out of the App Store review queue. Works until Apple approves it"
    end
  end
end
