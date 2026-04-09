# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.5.7] - 2026-04-09

### Added

- `auto_route` tab config option for controlling tab routing. Accepts `false` (disable routing for this tab) or an array of route prefixes (replaces the default prefix match on `path`). Trailing slash routes like `/breweries/` match sub-paths but not the bare path. Omit `auto_route` to keep the default behavior (prefix match on the tab's `path`).

## [0.5.5] - 2026-04-08

### Added

- `eager: true` tab config example to the install generator's YAML template. Set `eager: true` on a tab to load it on app launch instead of when first tapped.

## [0.5.3] - 2026-04-08

### Fixed

- Apple webhook endpoint now handles `TEST` notification type. Previously, test notifications sent via the App Store Server API's "Request a Test Notification" endpoint would return HTTP 500 because the processor tried to decode a `signedTransactionInfo` that doesn't exist in test payloads. The endpoint now returns 200 immediately for `TEST` notifications without processing.

## [0.5.0] - 2026-04-06

### Breaking

- **Always edge-to-edge.** The `edge_to_edge` config option has been removed. The web view always extends behind the status bar and Dynamic Island. Add the `native-inset` CSS class to your content wrapper to handle safe area spacing (see below).
- **`status_bar_color` renamed to `background_color`.** The old `background_color` (unused at runtime) has been removed. The new `background_color` is the unified window background color, visible during app launch and transitions. Set it to match your CSS body background or omit it.
- **`viewport-fit=cover` injected automatically.** The JavaScript bridge now injects `viewport-fit=cover` into the viewport meta tag at document start. This enables CSS `env(safe-area-inset-*)` variables. No manual viewport changes needed.

### Added

- `native-inset`, `native-inset-top`, and `native-inset-bottom` CSS utility classes in the gem stylesheet. These use `::before`/`::after` pseudo-elements so they stack with existing padding utilities like `pb-8`. Include the stylesheet with `stylesheet_link_tag :ruby_native`.
- `native_overscroll_tag` ERB helper for per-page overscroll colors. Declares top and bottom colors that are dynamically swapped based on scroll position, solving the WKWebView limitation of a single `background-color` for all overscroll directions. Usage: `native_overscroll_tag(top: "#f0f9ff", bottom: "#f5f1ea")`.
- `NativeOverscroll` component for React and Vue Inertia apps. Usage: `<NativeOverscroll top="#f0f9ff" bottom="#f5f1ea" />`.
- Overscroll color logic in the bundled JavaScript. Detects `data-native-overscroll-top` and `data-native-overscroll-bottom` signal elements via the MutationObserver and swaps `html` background-color based on scroll position. Works with Turbo and Inertia navigation.

### Upgrade guide

1. Update `config/ruby_native.yml`: remove `edge_to_edge` and `status_bar_color`. Rename your old `status_bar_color` value to `background_color` (or remove the old `background_color` if it was the same).
2. Add `<%= stylesheet_link_tag :ruby_native %>` to your layout `<head>` if not already present.
3. Add the `native-inset` class to your main content wrapper: `<main class="native-inset">`.
4. For fixed navbars, add `native-inset-top` to the `<nav>` element.

## [0.4.2] - 2026-04-04

### Added

- `appearance.landscape` config option. Set `landscape: true` in `config/ruby_native.yml` to allow landscape orientation on iPhone. Defaults to portrait only.

## [0.4.1] - 2026-03-31

### Added

- `enabled` prop on `NativeTabs` for React and Vue Inertia components. Pass `enabled={false}` (React) or `:enabled="false"` (Vue) to dynamically hide the tab bar, for example during edit mode. Defaults to `true`.

## [0.4.0] - 2026-03-31

### Breaking

- `RubyNative::InertiaSupport` shared props renamed from `native_app`/`native_form` to `nativeApp`/`nativeForm` to match JavaScript naming conventions. Update your Inertia components to use the new camelCase names.
- **Vite + Inertia apps:** The gem's React and Vue entry points now import from `@inertiajs/react` and `@inertiajs/vue3` respectively. If you resolve the gem's JavaScript via a Vite path alias, add the Inertia package to `resolve.dedupe` in your `vite.config.ts` to prevent Vite from resolving it relative to the gem's bundler path instead of your app's `node_modules`:

  ```js
  // React
  dedupe: ["react", "react-dom", "@inertiajs/react"],

  // Vue
  dedupe: ["vue", "@inertiajs/vue3"],
  ```

### Added

- `native_navbar_tag` ERB helper for rendering a native navigation bar in Normal Mode. Supports trailing/leading buttons with icons, `href` navigation, `click` element targeting, and nested menu items via a builder API. Includes `submit_button` for native form submission.
- `NativeNavbar`, `NativeButton`, `NativeMenuItem`, and `NativeSubmitButton` components for React (`ruby_native/react`) and Vue (`ruby_native/vue`) Inertia apps. Render signal elements that the native bridge parses into a native navigation bar with buttons, menus, and submit actions.
- `native-hidden` CSS class. Elements with this class are hidden when running inside the native app. Use for web UI that has a native equivalent (e.g., buttons targeted by `click`). Requires the gem stylesheet (`stylesheet_link_tag :ruby_native`).
- `ruby_native deploy` CLI command triggers an iOS build from the terminal, polls for status, and reports success or failure. Links to your app on first run and saves the selection. Blocks concurrent deploys when a build is already in progress.

## [0.3.2] - 2026-03-24

### Added

- `native_badge_tag` helper for updating the app icon badge and tab bar badge from page loads. Works in both Normal Mode (via `data-native-badge` signal element) and Advanced Mode (via `bridge--badge` Stimulus controller). Pass a single count to set both badges, or use `home:` and `tab:` keyword arguments for independent control. Omitted parameters leave that badge unchanged.
- `RubyNative.setBadge(5)` JavaScript API for updating badges programmatically. Accepts a number (sets both) or an object with `home` and `tab` keys.
- `badge: true` tab config option in `config/ruby_native.yml` to designate which tab receives the tab bar badge.

## [0.3.1] - 2026-03-19

### Added

- `appearance.theme` config option to force light or dark mode. Accepts `light`, `dark`, or `auto` (default). When omitted, follows the device setting.

## [0.3.0] - 2026-03-18

### Added

- `ruby_native login` and `ruby_native logout` CLI commands for authenticating with the Ruby Native platform via browser-based OAuth flow.
- `ruby_native screenshots` CLI command captures web screenshots via Playwright, then uploads them to the platform for compositor processing. Prompts for Playwright install on first run. Auto-links to an app on your account and persists the selection in `config/ruby_native.yml`. Pass `--url` to capture from a different host (e.g., a production or staging URL).
- Install generator adds `.ruby_native/` to `.gitignore`.

## [0.2.9] - 2026-03-16

### Fixed

- Preview QR code no longer garbles the first line of output in process managers like Overmind. Replaced the terminal-clear escape sequence with simple newline spacing.

## [0.2.8] - 2026-03-16

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
