# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Fixed

- `import "ruby_native/bridge"` now resolves correctly for importmap-rails apps. Previously, the barrel import was pinned as `ruby_native/bridge/index` which required users to manually add the pin. The gem's importmap config now explicitly pins `ruby_native/bridge` to the index file.
- Install generator now prints Advanced Mode setup instructions (pinning `@hotwired/hotwire-native-bridge` and adding the import) so users aren't left guessing.

## [0.2.7] - 2026-03-11

### Added

- `native_haptic_data` helper for triggering device haptics on tap. Works in both Normal Mode (via `data-native-haptic` attribute) and Advanced Mode (via `bridge--haptic` Stimulus controller). Accepts a feedback type: `:success` (default), `:warning`, `:error`, `:impact`, or `:selection`. Unknown and blank values default to `:success`.
- `RubyNative.haptic("success")` JavaScript API for triggering haptics programmatically.
- `RubyNative.postMessage()` JavaScript API that wraps the native message handler. All internal JS-to-native communication now routes through this method.

### Changed

- `native_form_data` now accepts `**data` keyword arguments and merges the `controller` key instead of clobbering it. Existing usage without arguments is unchanged.
- `native_back_button_tag` onclick now uses `RubyNative.postMessage()` instead of calling `webkit.messageHandlers` directly.

### Added

- `tabs` is now optional in `config/ruby_native.yml`. Omit it to show a single full-screen web view without a tab bar. The app loads `entry_path` or falls back to `/`.
- Config endpoint returns an `X-Ruby-Native-Version` response header with the gem version.
- Tapping the version number on the error screen opens a detail sheet with the full error message, app version, gem version, and a copy-to-clipboard button.

### Changed

- Tab bar is only shown when two or more tabs are configured. A single tab no longer renders an empty-looking tab bar.
- `entry_path` now defaults to the first tab's path (then `/`) instead of always falling back to `/`.

## [0.2.6] - 2026-03-10

### Added

- `appearance.edge_to_edge` config option to let the web view extend behind the status bar and Dynamic Island. Enables full-bleed backgrounds, gradients, and images. Normal Mode only.

### Fixed

- Session cookies no longer silently fail through the Cloudflare preview tunnel. Apps that configure `domain: :all` on their session store had cookies scoped to `.trycloudflare.com` (a public suffix), which browsers and WKWebView reject. A new middleware automatically strips the `domain` attribute from cookies on tunnel requests so they scope to the exact hostname instead.

## [0.2.5] - 2026-03-09

### Added

- `app.entry_path` config option to control the initial URL on app launch. Defaults to the first tab's path, then `/`. Removes the need for server-side redirects to route native users to the right page.

## [0.2.4] - 2026-03-09

### Fixed

- OAuth middleware no longer relaxes `SameSite` on session cookies for non-native requests. Previously, all requests to configured `auth.oauth_paths` had their cookies changed to `SameSite=None; Secure`, which silently dropped session cookies in non-HTTPS environments like Rails integration tests.

## [0.2.3] - 2026-03-08

### Added

- Inertia.js support for React and Vue apps. Include `RubyNative::InertiaSupport` in your application controller to share `native_app` and `native_form` props automatically.
- React signal components (`NativeTabs`, `NativePush`, `NativeForm`) importable from `ruby_native/react`.
- Vue signal components (`NativeTabs`, `NativePush`, `NativeForm`) importable from `ruby_native/vue`.

### Changed

- Removed importmap pins for `ruby_native/react` and `ruby_native/vue`. Inertia apps resolve these via the Vite alias instead.
- `RubyNative::InertiaSupport` raises a clear error if the `inertia_rails` gem is not installed.

## [0.2.2] - 2026-03-07

### Fixed

- OAuth redirect loop when Devise (or similar) stores the OAuth start page as the post-login redirect. The middleware now replaces `/native/auth/start/*` redirect URLs with `/` before building the token.

## [0.2.1] - 2026-03-07

### Fixed

- OAuth start page now uses the path from `auth.oauth_paths` in config instead of hardcoding `/auth/{provider}`. Fixes 404 errors for apps that mount OmniAuth at a custom prefix like `/users/auth/`.

## [0.2.0] - 2026-03-04

### Changed

- User agent now includes `RubyNative/X.Y.Z` package version token. `native_version` returns the package version instead of the app version, making it consistent across all apps built with Ruby Native.
- `native_version` returns `"0"` for older apps that don't include the `RubyNative/` token.

## [0.1.10] - 2026-03-05

### Added

- OAuth support for native apps. Add `auth.oauth_paths` to `config/ruby_native.yml` to enable Sign in with Google, Apple, and other providers.
- `native_version` helper for version-gating features in views, e.g. `native_version >= "1.4"`.

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
