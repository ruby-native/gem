# Ruby Native

Turn your Rails app into an iOS app. Any frontend framework. No Xcode required.

## Quick start

1. Add the gem to your Gemfile and bundle:

```ruby
gem "ruby_native"
```

2. Run the install generator:

```bash
rails generate ruby_native:install
```

3. Edit `config/ruby_native.yml` with your app name, colors, and tabs.

4. Add to your layout `<head>`:

```erb
<%= stylesheet_link_tag :ruby_native %>
```

5. Add to your layout `<body>`:

```erb
<%= native_tabs_tag %>
```

6. Preview on your phone:

```bash
bundle exec ruby_native preview
```

Scan the QR code with the Ruby Native Preview app from the App Store.

## Configuration

`config/ruby_native.yml` controls the native shell. Changes are picked up without restarting the server in development.

```yaml
app:
  name: My App

appearance:
  tint_color: "#007AFF"
  background_color: "#FFFFFF"
  status_bar_color: "#F8F9FA"

tabs:
  - title: Home
    path: /
    icon: house
  - title: Profile
    path: /profile
    icon: person
```

Icons use SF Symbols names (e.g., `house`, `person`, `envelope`, `gear`).

### Dark mode

Color fields accept a plain hex string or an object with `light` and `dark` keys:

```yaml
background_color:
  light: "#FFFFFF"
  dark: "#212529"
status_bar_color:
  light: "#F8F9FA"
  dark: "#2B3035"
```

Match these to your CSS framework's dark mode colors. For Bootstrap, `#212529` is `--bs-body-bg` and `#2B3035` is `--bs-tertiary-bg` in dark mode.

## View helpers

Use these in your layouts and views:

- `native_app?` returns true when the request comes from a Ruby Native app. Use it to hide web-only UI like navbars.
- `native_tabs_tag` renders a signal element that tells the app to show the tab bar. Only include it on pages where tabs should appear.
- `native_form_tag` marks the page as a form. The app uses this to skip form pages when navigating back.
- `native_push_tag` requests push notification permission from the user.

Signal elements are hidden `<div>` tags. Place them in the `<body>`, not the `<head>`.

### Example layout

```erb
<body>
  <%= native_tabs_tag if user_signed_in? %>
  <%= render "navbar" unless native_app? %>
  <%= yield %>
</body>
```

## Preview

`bundle exec ruby_native preview` starts a Cloudflare tunnel and displays a QR code. Requires `cloudflared`:

```bash
brew install cloudflare/cloudflare/cloudflared
```

Options:
- `--port 3001` to specify the local server port (defaults to 3000)

The install generator adds `.trycloudflare.com` to `config.hosts` in `development.rb` automatically. If you skipped the generator, add it manually:

```ruby
# config/environments/development.rb
config.hosts << ".trycloudflare.com"
```

The Preview app remembers the scanned URL. Long-press the app icon and tap "Switch website" to scan a new server.

## Endpoints

The gem auto-mounts at `/native`. No route configuration needed.

- `GET /native/config` returns the YAML config as JSON
- `POST /native/push/devices` registers a push notification device token

## Common tasks

### Hide web navigation in the native app

```erb
<%= render "navbar" unless native_app? %>
```

### Show tabs only for signed-in users

```erb
<%= native_tabs_tag if user_signed_in? %>
```

### Add a native back button

Add an element with the `native-back-button` class. The gem's stylesheet handles showing it only when there's history to go back to.

```erb
<%= stylesheet_link_tag :ruby_native %>
```

```erb
<button class="native-back-button" onclick="webkit.messageHandlers.rubyNative.postMessage({action: 'back'})">
  Back
</button>
```
