# Ruby Native for Claude Code

[Ruby Native](https://rubynative.com) turns a Rails app into iOS and Android apps. This plugin gives your coding agent the `ruby_native` MCP server, so it can check the views and config it writes, read where the app stands, and run every store step that has a tool, stopping at the ones only a person can take.

## What it runs

The server is the `ruby_native` gem already in your Gemfile, started by [`bin/ruby-native-mcp`](bin/ruby-native-mcp), which runs `bundle exec ruby_native mcp` in your project directory. Nothing is downloaded or installed by the plugin itself. Install the gem first:

```ruby
gem "ruby_native"
```

## What it sends, and where

Three tools answer from your working copy and never leave your machine: `check_views`, `lookup_signals`, and `validate_config`. The rest talk to rubynative.com, Ruby Native's own API, with your Ruby Native token: `status`, `config_errors`, `deployed_builds`, `build_status`, the staging tools (`icon_set`, `permissions_set`, `testers_add`, `screenshots_setup`, `screenshots_capture`, `listing_push`, `listing_pull`, `demo_account_set`), and `submit` and `withdraw`, which reach Apple through Ruby Native. `submit` takes two calls with a token in between, so the agent shows you what goes to review and sends only on your yes.

## The token

The plugin asks for an optional **Ruby Native token** and passes it to the server as `RUBY_NATIVE_TOKEN`. Leave it blank and the account tools use the login that `ruby_native login` stored on this machine. A token from your dashboard's CI settings works too.

## Start

Say: set up Ruby Native in this app. Or run the prompt the server publishes, `/mcp__ruby-native__ship`, which walks every step to the App Store and Google Play. The full reference is at [rubynative.com/docs/cli](https://rubynative.com/docs/cli#mcp-server).
