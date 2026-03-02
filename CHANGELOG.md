# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.2] - 2026-03-01

### Fixed

- Config endpoint now always includes `app.name` in JSON response, defaulting to "Ruby Native". Fixes compatibility with older versions of the Preview app.

## [0.1.1] - 2026-02-27

- Added default chevron icon SVG to web-based back button

## [0.1.0] - 2026-02-25

### Added

- Advanced Mode with native navigation bar, screen transitions, and swipe-to-go-back.
- Six bridge controllers (`tabs`, `form`, `button`, `push`, `menu`, `search`) registered via `import "ruby_native/bridge"`.
- `native_form_data` and `native_submit_data` helpers for native submit buttons that disable during form submission.
- `native_button_tag` helper for native navigation bar buttons with SF Symbol icons and left/right placement.
- `native_menu_tag` helper for native action sheet menus with destructive item support.
- `native_search_tag` helper for native search bars that dispatch query events.
- Bridge component CSS in the gem's stylesheet. Web submit buttons and native button elements are automatically hidden when their bridge components are active.

## [0.0.6] - 2026-02-24

- Fix potential issue with rendered QR code

## [0.0.5] - 2026-02-24

### Fixed

- Generator copies CLAUDE.md with `copy_file` instead of `template` to avoid ERB evaluation errors.
- Removed erroneous `.json` extension from config endpoint path in generated documentation.

## [0.0.4] - 2026-02-16

No functional changes. Version bump only.

## [0.0.3] - 2026-02-13

### Added

- `rails generate ruby_native:install` generator.
- Generator creates `config/ruby_native.yml` with sensible defaults.
- Generator adds `.trycloudflare.com` to allowed hosts in `development.rb`.
- Generator copies `.claude/ruby_native.md` if a `.claude/` directory exists.
- Config controller reloads config on each request in development.
- Dark mode documentation (light/dark color objects).

### Changed

- Improved CLI usage output with list of available commands.
- Updated README with generator-based getting started flow.

## [0.0.2] - 2026-02-11

### Added

- `bundle exec ruby_native preview` CLI command with Cloudflare tunnel and QR code.
- `--port` option for specifying local server port (defaults to 3000).
- `rqrcode` gem dependency.
- MIT LICENSE.

## [0.0.1] - 2026-02-11

### Added

- Rails engine auto-mounted at `/native`.
- `GET /native/config` endpoint returning YAML config as JSON.
- `POST /native/push/devices` endpoint for push token registration.
- `native_app?` helper for detecting native app requests.
- `native_tabs_tag`, `native_form_tag`, `native_push_tag` signal element helpers.
- `ruby_native.css` stylesheet with native back button support.
- `RubyNative::NativeDetection` controller concern.
