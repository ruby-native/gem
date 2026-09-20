# ruby_native

[Ruby Native](https://rubynative.com) turns a Rails app into iOS and Android apps. This gem is the Rails-side integration: view helpers, a YAML config file, endpoints auto-mounted at `/native`, and a CLI for previewing and deploying builds. Full docs, including the complete helper reference and config schema, live at [rubynative.com/docs](https://rubynative.com/docs).

## Installation

```ruby
gem "ruby_native"
```

The engine auto-mounts at `/native`. No route configuration needed.

## Getting started

Run the install generator:

```bash
rails generate ruby_native:install
```

This creates `config/ruby_native.yml`. Then:

1. Edit the config with your colors and tabs (see below).
2. Add the stylesheet and `viewport-fit=cover` to your layout `<head>`:

   ```erb
   <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
   <%= stylesheet_link_tag :ruby_native %>
   ```

   `viewport-fit=cover` is required for CSS `env(safe-area-inset-*)` variables to resolve to real values instead of `0`.
3. Add the tab bar to your layout `<body>`:

   ```erb
   <%= native_tabs_tag %>
   ```
4. Preview it on your phone (see below).

The full walkthrough, including safe area layout and hiding web-only navigation with `native_app?`, is at [rubynative.com/docs/setup](https://rubynative.com/docs/setup).

## Configuration

`config/ruby_native.yml` controls the native shell:

```yaml
appearance:
  tint_color: "#007AFF"
  background_color: "#FFFFFF"

tabs:
  - title: Home
    path: /
    icon: house
  - title: Profile
    path: /profile
    icon: person
```

Changes are picked up without restarting the server in development. See [rubynative.com/docs](https://rubynative.com/docs) for the full schema: appearance and dark mode, navbar branding, Advanced Mode, OAuth, and linked domains.

## Preview

Preview your app on a real device without deploying:

```bash
bundle exec ruby_native preview
```

This starts a Cloudflare tunnel and shows a QR code for the Ruby Native app to scan. Your Rails server needs to be running separately. Requires `cloudflared`:

```bash
brew install cloudflare/cloudflare/cloudflared
```

The tunnel points at port 3000, or at `PORT` when it is set, the same way `rails server` picks its port. Pass `--port 4000` to override, or `--url` for an upstream that isn't on localhost.

See [rubynative.com/docs/cli](https://rubynative.com/docs/cli) for `deploy`, `login`, and auto-deploying from CI.

## React and Vue

Building with Inertia instead of ERB? `@ruby-native/react` and `@ruby-native/vue` provide the same helpers as npm packages, versioned alongside this gem. See [rubynative.com/docs/inertia](https://rubynative.com/docs/inertia) for setup.

## AI agents

Every docs page serves markdown: append `.md` to the URL or request `Accept: text/markdown`. For an index of everything, fetch [rubynative.com/llms.txt](https://rubynative.com/llms.txt), or [llms-full.txt](https://rubynative.com/llms-full.txt) for the complete docs as a single file.

### MCP server

Docs tell an agent what to write. They don't tell it whether what it wrote works, and Ruby Native's signals fail silently on purpose: an app that doesn't recognize a `data-native-*` attribute ignores it. A typo renders nothing, raises nothing, and logs nothing, so it survives right up until someone opens the build and notices the missing button.

`ruby_native mcp` closes that loop. It speaks [MCP](https://modelcontextprotocol.io) over stdin and stdout. Three tools answer from your working copy, with no account involved:

| Tool | Answers |
|---|---|
| `check_views` | Which signals in your templates are misspelled, duplicated, or newer than the installed gem |
| `lookup_signals` | Every `data-native-*` attribute, the gem version it needs, and the helper that emits it |
| `validate_config` | What in `config/ruby_native.yml` the apps reject outright, and what they quietly ignore |

Three more read your account, using the token `ruby_native login` already stored:

| Tool | Answers |
|---|---|
| `config_errors` | What real devices reported failing over the last 48 hours, with the decode error behind each one |
| `deployed_builds` | The build your users can actually install, and which signals it's too old to understand |
| `build_status` | Whether one build succeeded, and the error if it didn't |

The pairs are the point. `validate_config` says what *will* fail to decode; `config_errors` says what did, on which devices. `check_views` compares your templates against the gem in your Gemfile; `deployed_builds` compares them against the binary in the store, which is usually the answer to "the attribute is right but nothing happens on my phone".

Register it with any MCP client. For Claude Code:

```bash
claude mcp add ruby-native -- bundle exec ruby_native mcp
```

Or, in a client that takes JSON:

```json
{
  "mcpServers": {
    "ruby-native": {
      "command": "bundle",
      "args": ["exec", "ruby_native", "mcp"]
    }
  }
}
```

Everything is read-only: nothing here deploys or writes. The first three never leave your machine; the second three send your CLI token to rubynative.com and read back. `check_views` needs the `herb` gem, same as `ruby_native check`.

## License

MIT.
