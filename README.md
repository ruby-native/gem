# ruby_native gem

A Rails engine that provides native detection, configuration, push device registration, and view helpers for Ruby Native iOS and Android apps.

## Installation

```ruby
gem "ruby_native"
```

The engine auto-mounts at `/native`. No route configuration needed.

## Getting started

Run the install generator to create your config file:

```bash
rails generate ruby_native:install
```

This creates `config/ruby_native.yml` with sensible defaults. If you have a `.claude/` directory, it also adds `.claude/ruby_native.md` with AI-assisted setup instructions. Follow the printed instructions to:

1. Edit the config with your app name, colors, and tabs
2. Add `<%= stylesheet_link_tag :ruby_native %>` to your layout `<head>`
3. Add `<%= native_tabs_tag %>` to your layout `<body>`
4. Run `ruby_native preview` to see it on your phone

Using Claude Code? Open it in your project and ask "what do I need to do next?" for guided setup.

## Configuration

Edit `config/ruby_native.yml`:

```yaml
app:
  name: My App
appearance:
  tint_color: "#4F46E5"
  background_color: "#FFFFFF"
  status_bar_color: "#FFFFFF"
tabs:
  - title: Home
    path: /
    icon: house
  - title: Profile
    path: /profile
    icon: person
```

Color fields accept a plain hex string or an object with `light` and `dark` keys for dark mode:

```yaml
background_color:
  light: "#FFFFFF"
  dark: "#1C1C1E"
```

## Preview

Preview your app on a real device without deploying. This starts a Cloudflare tunnel and displays a QR code for the companion app to scan.

```bash
ruby_native preview
```

Options:

- `--port 3001` - specify the local server port (defaults to 3000)

Requires `cloudflared`. Install with:

```bash
brew install cloudflare/cloudflare/cloudflared
```

The companion app persists the scanned URL across launches. Long-press the app icon and tap "Switch website" to scan a new server.

## Endpoints

- `GET /native/config` - returns the YAML config as JSON
- `POST /native/push/devices` - registers a push notification token (requires `current_user` from host app)

## View helpers

- `native_app?` - true when the request comes from a Ruby Native app (checks user agent)
- `native_tabs_tag` - renders a hidden signal element for tab bar detection
- `native_form_tag` - renders a hidden signal element marking the page as a form
- `native_push_tag` - renders a hidden signal element requesting push permission

Signal elements are hidden `<div>` tags with data attributes (e.g., `<div data-native-tabs hidden>`). Place them in the `<body>`, not the `<head>`.

## Stylesheet

The gem includes `ruby_native.css` which controls back button visibility:

```erb
<%= stylesheet_link_tag :ruby_native %>
```

This shows `.native-back-button` elements only when `body.can-go-back` is set by the native app.
