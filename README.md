# ruby_native gem

A Rails engine that provides native detection, configuration, push device registration, and view helpers for Ruby Native iOS and Android apps.

## Installation

```ruby
gem "ruby_native", path: "../../gem"  # local development
```

Then mount the engine in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount RubyNative::Engine => "/native"
end
```

## Configuration

Create `config/ruby_native.yml`:

```yaml
app:
  name: My App
appearance:
  tint_color: "#4F46E5"
  background_color: "#FFFFFF"
  status_bar: dark
  status_bar_color: "#FFFFFF"
tabs:
  - title: Home
    path: /
    icon: house
  - title: Profile
    path: /profile
    icon: person
```

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
