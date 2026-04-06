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
4. Run `bundle exec ruby_native preview` to see it on your phone

Using Claude Code? Open it in your project and ask "what do I need to do next?" for guided setup.

## Configuration

Edit `config/ruby_native.yml`:

```yaml
appearance:
  tint_color: "#4F46E5"
  background_color: "#FFFFFF"
tabs:  # optional
  - title: Home
    path: /
    icon: house
  - title: Profile
    path: /profile
    icon: person
```

You may also omit `tabs` to hide the tab bar entirely. The app will load `entry_path` or fall back to `/`.

Color fields accept a plain hex string or an object with `light` and `dark` keys for dark mode:

```yaml
background_color:
  light: "#FFFFFF"
  dark: "#1C1C1E"
```

## Preview

Preview your app on a real device without deploying. This starts a Cloudflare tunnel and displays a QR code for the companion app to scan.

```bash
bundle exec ruby_native preview
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

## Normal and Advanced Modes

Normal Mode works with any frontend framework and requires no JavaScript. You get tabs, form page marking, push notifications, and history management.

Advanced Mode adds native navigation bar buttons, submit buttons, action menus, and search bars. It requires Stimulus and a small JavaScript setup step (see [Advanced Mode setup](#advanced-mode-setup) below). Migration is additive. Start with Normal and add Advanced helpers one page at a time.

## View helpers

Place helpers in the `<body>`, not the `<head>`.

### Any mode

- `native_app?` - true when the request comes from a Ruby Native app (checks user agent)
- `native_version` - returns the app version as a `RubyNative::NativeVersion`. Defaults to `"0"` when the version is unknown. Supports string comparisons: `native_version >= "1.4"`.
- `native_tabs_tag(enabled: true)` - shows the native tab bar.
- `native_push_tag` - requests push notification permission.
- `native_back_button_tag(text = nil, **options)` - renders a back button for Normal Mode. Hidden by default, shown when the native app sets `body.can-go-back`. Not needed in [Advanced Mode](https://rubynative.com/docs/advanced-mode) where the system provides a native back button.

### Normal Mode

- `native_form_tag` - marks the page as a form. The app skips form pages when navigating back.

### Advanced Mode

These require the JavaScript setup described in [Advanced Mode setup](#advanced-mode-setup).

- `native_form_data` - returns the data hash for the native form submit button. Pass to `form_with`'s `data:` option.
- `native_submit_data` - returns the data hash for the native submit target. Pass to `form.submit`'s `data:` option.
- `native_button_tag(title, url, ios_image:, side: :right, **options)` - adds a native navigation bar button.
- `native_menu_tag(title:, side: :right, &block)` - displays a native action sheet menu.
- `native_search_tag` - adds a native search bar.

## Advanced Mode setup

1. Install the JavaScript dependency:

```bash
yarn add @hotwired/hotwire-native-bridge
# or
bin/importmap pin @hotwired/hotwire-native-bridge
```

2. Import the controllers in your JavaScript entrypoint:

```js
import "ruby_native/bridge"
```

### `native_form_data` / `native_submit_data`

```erb
<%= form_with model: @link, data: native_form_data do |f| %>
  <%= f.text_field :url %>
  <%= f.submit "Save", data: native_submit_data %>
<% end %>
```

### `native_button_tag`

```erb
<%= native_button_tag "Add a link", new_link_path, ios_image: "plus", class: "btn btn-primary" %>
```

Options:
- `ios_image:` - SF Symbol icon name (falls back to the title text)
- `side:` - `:left` or `:right` (default). Left supplements the back button.

### `native_menu_tag`

```erb
<%= native_menu_tag(title: "Actions") do |menu| %>
  <%= menu.item "Edit", edit_link_path(@link) %>
  <%= menu.item "Delete", link_path(@link), method: :delete, destructive: true %>
<% end %>
```

Options on `native_menu_tag`:
- `title:` - action sheet title
- `side:` - `:left` or `:right` (default)

Options on `menu.item`:
- `method:` - Turbo method (e.g., `:delete`)
- `destructive: true` - red styling

## Stylesheet

The gem includes `ruby_native.css` which controls back button visibility:

```erb
<%= stylesheet_link_tag :ruby_native %>
```

This shows `.native-back-button` elements only when `body.can-go-back` is set by the native app.
