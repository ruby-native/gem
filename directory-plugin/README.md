# Ruby Native

[Ruby Native](https://rubynative.com) turns a Rails app into iOS and Android apps and takes them to the App Store and Google Play. This plugin is one skill that teaches Claude the whole journey: the first native pass on your views and config, the Ruby Native account, and every store step, stopping at the ones only a person can take.

## What it runs

The plugin runs nothing on its own. In Claude Code, the skill has Claude run the `ruby_native` command line from the gem already in your Gemfile, such as `bundle exec ruby_native status` and `bundle exec ruby_native check`, with the same permission prompts as any other command. In claude.ai and Cowork, it tells you which command to run and reads the output you paste back. Install the gem first:

```ruby
gem "ruby_native"
```

## What it sends, and where

The plugin sends nothing itself. `check` reads your working copy and never leaves your machine. Commands like `status`, `deploy`, `listing push`, and `submit` talk to rubynative.com, Ruby Native's own API, using the login `ruby_native login` stored on your machine. `submit` prints what would go to App Store review and sends only when run again with `--yes`, after you say yes.

## More tools

For Claude Code, Ruby Native also has an MCP server with richer tools, like checking views against the build in the store. Add it to a project with `bundle exec ruby_native mcp install`. The full reference is at [rubynative.com/docs/cli](https://rubynative.com/docs/cli).

## Start

Say: set up Ruby Native in this app.

## License

MIT
