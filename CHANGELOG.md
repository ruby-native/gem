# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- **`ruby_native preview` ends with a next step.** Until you've logged in from that machine, stopping the preview points you at a free TestFlight build.

### Fixed

- **`ruby_native preview` tells you when the QR code won't fit your terminal.** It printed a wrapped code that couldn't scan before. Widen the window or paste the URL.

## [0.17.1] - 2026-09-05

### Fixed

- **A paywall written the way the docs show now records the purchase.** Subscriptions bought through it never reached your Rails app before. Needs a build on this release or later. iOS.
- **`ruby_native check` and `deploy` no longer reject a paywall written the way the docs show.** They reported `data-native-customer-id` and `data-native-success-path` as unknown signals since 0.16.0.

## [0.17.0] - 2026-09-05

### Added

- **Turn off the launch ping with `analytics: false` in `config/ruby_native.yml`.** Needs a build on this release or later. Both platforms, both modes. [Docs](https://rubynative.com/docs/setup#usage-reporting)
- **Your dashboard shows each app's monthly active devices, split by platform, with a daily trend.**

### Changed

- **Advanced Mode is out of beta.**

### Fixed

- **Inputs stay above the keyboard on Android devices whose WebView predates version 139.** The keyboard covered them since 0.16.0. Both modes.
- **iOS apps now report a failed config load to your dashboard.** Only Android apps did before.

### Removed

- **The "temporarily unavailable" screen is gone from both apps.** Both platforms, both modes.

## [0.16.0] - 2026-09-03

### Added

- **New `ruby_native check` command finds broken signals in your views before they reach the App Store.** Needs the `herb` gem, which Rails 8.2 and later already include. [Docs](https://rubynative.com/docs/debugging)

### Changed

- **`deploy` now builds every platform you have configured, not just iOS.** Use `--ios` to build one, the way `--android` already did.
- **`deploy` now fails when any platform fails.** It reported only the first build before, so a failed Android build could pass behind a successful iOS one.
- **`deploy` now checks your views for broken signals before starting a build.** Pass `--skip-check` to skip it.
- **The keyboard now scrolls the page instead of resizing it, matching iOS.** Screens without a tab bar used to shrink the page to fit above the keyboard, so a full-height layout reflowed as it opened. Advanced Mode on Android.

### Fixed

- **A text field at the bottom of the page is no longer hidden behind the keyboard.** Tapping it opened the keyboard over the field with nothing on the page moving out of the way. Normal Mode on Android.
- **The floating action button now hides while the keyboard is open.** It used to slide up and land on top of whatever your page anchors to the bottom, like a chat composer. Advanced Mode on Android.

## [0.15.3] - 2026-08-31

### Added

- **Tab bar titles can now be translated in your app's own locale files.** Give a tab a `key:`, put its copy under `ruby_native.tabs.<key>.title`, and the device's language picks the translation. Both platforms. [Docs](https://rubynative.com/docs/tabs#localization)

## [0.15.2] - 2026-08-28

### Fixed

- **Deep links now open the linked page when the app isn't already running.** App Links and tapped notifications landed on the home screen instead when `appearance.theme` was set to the opposite of the device's theme. Advanced Mode on Android.

## [0.15.1] - 2026-08-27

### Changed

- **Android tabs now load when first tapped, matching iOS.** Every tab loaded at launch before, whatever the config said; `eager: true` tabs still load up front. Advanced Mode on Android.
- **With no `background_color` set, Android pages now sit on pure white, or near-black in dark mode.** The default carried a faint cast of the tint color before.

### Fixed

- **An app with no `appearance` block in `config/ruby_native.yml` now launches.** It showed the error screen on every launch before. Both platforms.
- **Menus, segmented controls, and selected navbar buttons on Android now use your tint color.** They showed Material's default purple, whatever `tint_color` said. Advanced Mode.
- **JavaScript `alert`, `confirm`, and `prompt` dialogs now use your tint color on Android.** They showed Material's default purple in Advanced Mode before. Both modes.
- **Signing in now refreshes the other tabs.** A tab that had already loaded while signed out kept its signed-out page, telling the user to sign in again. Advanced Mode, both platforms.
- **Selecting a tab last loaded while signed out no longer resets the app to the first tab.** Advanced Mode, both platforms.
- **Tapping a push notification now opens its `path` while the app is running.** The tap only brought the app back to the foreground before. Advanced Mode on Android.
- **Tapping an App Link while the app is already running now opens the linked page.** It worked only when the app wasn't running before. Advanced Mode on Android.
- **Tapping a push notification with a `path` no longer crashes the app on a cold start.** Advanced Mode on Android.
- **The app no longer launches showing an `eager: true` tab.** It starts on the first tab, with the eager tab preloaded behind it. Advanced Mode on iOS.

## [0.15.0] - 2026-08-25

### Added

- **New `native_keyboard_tag` hides the previous/next/Done bar above the keyboard.** For chat screens where the composer should sit flush against the keyboard, the way it does in Messages. iOS only. [Docs](https://rubynative.com/docs/keyboard)
- **`NativeKeyboard` is available for React and Vue**, matching the Rails helper.

### Changed

- **Dragging a page down now dismisses the keyboard.** iOS, both modes.

### Fixed

- **Android builds no longer request photo and video permissions, so Google Play's "Photo and video permissions" declaration no longer appears.** Previously requested whenever `permissions.photo_library` was set; file uploads are unaffected.
- **Android debug builds trust certificates you've installed on the device, so local HTTPS domains (puma-dev, mkcert) now load.** Release builds are unchanged.
- **The React and Vue components now behave exactly like the Rails helpers.** `NativeFab` no longer crashes web and server renders when only `icons` is given, share buttons show the right glyph on Android, and invalid `action`, `intent`, and `appearance` values raise a clear error instead of rendering a broken signal.
- **Native OAuth sign-in can no longer land in the wrong app.** The cookie that routes the flow back to the app now expires as soon as sign-in completes, so a stale one from an earlier attempt, or from another app on the same domain, no longer hijacks the redirect. Both platforms, both modes.
- **Writing a single `auth.oauth_paths` entry without a list no longer breaks the app.** `oauth_paths: /auth/google` used to fail the whole config and show an error screen on launch. Both platforms, both modes.
- **Android apps no longer stop responding after the system reclaims them in the background.** Returning to the app could leave every page unable to submit a form, follow a link, or run any of its JavaScript until it was force quit. Normal Mode on Android, in every release since 0.12.0.
- **Buttons, menu items, and FABs that set both `href` and `click` now follow the href.** They ran the click instead, the opposite of every other platform and mode. Advanced Mode on Android.
- **Your `errors` copy now reaches end users in Advanced Mode on Android.** They always saw the built-in English text there, whatever you configured.
- **A paywall with more than one purchase button now updates the button the customer tapped.** The first button on the page took the "Processing" and "Subscribed" states instead, and could be left stuck on "Processing". iOS.
- **A failed purchase now shows a plain message instead of raw system error text.** iOS.
- **A FAB with a `color` no longer reports a false "unknown signal" warning.** Both platforms, both modes.
- **VoiceOver now announces tab badge counts in Advanced Mode on iOS.** The badge was visible but silent.

## [0.14.3] - 2026-08-24

### Added

- **Set your Android tab bar's icon and label color with `appearance.android.tab_bar.foreground_color`.** The selected tab takes it at full strength and the rest dim to 60%, so a dark branded bar stays readable. Accepts a hex string or `{ light:, dark: }`. Both modes. [Docs](https://rubynative.com/docs/appearance)

### Fixed

- **Push notifications now work in Advanced Mode on Android.** A page with `native_push_tag` never asked for permission, so those apps could not receive a single notification.
- **Signing out or switching accounts in Advanced Mode on Android now clears the previous account from every tab.** Tabs you weren't looking at held on to the old session's pages. Apps that always show their tab bar were hit hardest, since nothing else on screen changed.
- **Switching accounts from a tab other than the first no longer leaves that tab's page under the first tab.** Normal Mode on Android.

## [0.14.2] - 2026-08-21

### Added

- **`native_os_build` reads the device's OS build from the User-Agent**, like `"23F79"` on iOS or `"UQ1A.240205.004"` on Android. `nil` on the web and in apps built before this release. Both platforms, both modes.

### Fixed

- **Share buttons no longer crash the app when appearance colors use `{ light:, dark: }` pairs.** Tapping any share control killed the app instantly if `tint_color` or `background_color` had light and dark values. iOS only, both modes.
- **Requests the app sends itself, like the push notification token POST, now carry the Ruby Native User-Agent.** They arrived as `okhttp/4.12.0` or a CFNetwork default before, so `native_app?` and the version helpers treated them as web traffic. Both platforms, both modes.
- **`appearance.theme` is now applied on Android.** Forcing `light` or `dark` had no effect; the app kept following the phone. Both modes.
- **Advanced Mode on Android no longer flashes a dark background while pages load in dark mode.** Screens now load against your `background_color`.
- **Pushing a screen in Advanced Mode on Android no longer flashes Material purple.** The moment before a page renders now shows your `background_color`, with the spinner in your `tint_color`.
- **Page content now matches a forced `appearance.theme` in Normal Mode on Android.** Under `theme: light` on a phone in dark mode, the bars went light but pages with dark-mode CSS still rendered dark.

## [0.14.0] - 2026-08-19

### Added

- **Attach a native menu to any element on the page with `native_menu_tag`.** Tapping the element pops a menu right on it, with icons, checkmarks, and red destructive rows: an anchored `UIMenu` on iOS, a Material dropdown on Android. Picking an item navigates or clicks a web element, exactly like a nav bar menu item. React and Vue get a matching `NativeMenu` component. Both platforms, both modes.
- **Menu items can render red with `destructive: true`**, for delete-style actions, in nav bar menus and in-content menus alike. Both platforms, both modes.
- **`ruby_native deploy` now relays notices from the server**, like a heads-up that a lapsed subscription payment sent an iOS release to TestFlight only. Future notices need no gem update.
- **YAML anchors and aliases now work in `config/ruby_native.yml`**, both in Rails and the CLI.
- **Android chrome is now a clean neutral gray in light and dark mode, instead of a Material-tinted surface you didn't pick.** The navigation bar, tab bar, and floating action button all go neutral, with your `tint_color` on the selected tab and accents, matching iOS. Advanced Mode gets the biggest fix: its bars and button previously ignored `tint_color` entirely and rendered Material's default purple. Both modes.
- **Override Android's bar colors with `appearance.android`.** Set `background_color` on `android.navbar` or `android.tab_bar` (the navbar also takes `foreground_color`), each a hex string or `{ light:, dark: }` for dark mode. Wins over the neutral defaults on Android without touching iOS, whose Liquid Glass bars Apple doesn't let apps recolor. Both modes. [Docs](https://rubynative.com/docs/appearance)
- **Color the floating action button right from the page**: `native_fab_tag icon: "plus", color: "#D97706"`. The button is tinted with it — tinted Liquid Glass on iOS, a colored Material FAB on Android — with the icon color derived automatically to stay readable. Pass `color: :tint` to inherit your `tint_color` instead of repeating the hex. React and Vue `NativeFab` take the same `color` prop. Both platforms, both modes. [Docs](https://rubynative.com/docs/fab)

### Fixed

- **Network problems no longer crash the CLI with a backtrace.** Connection failures say what went wrong and what to try next, and `ruby_native deploy` rides out brief blips while waiting for a build instead of dying mid-build.
- **`ruby_native deploy --if-needed` now asks you to log in again when your token expires**, instead of failing CI with an unhandled error. Auth errors also call out `RUBY_NATIVE_TOKEN` when it is set, since it overrides `ruby_native login`, and an empty `RUBY_NATIVE_TOKEN` no longer hides a valid login.
- **An empty `config/ruby_native.yml` no longer crashes Rails boot.** The file is skipped with a warning, and YAML syntax errors now name the file.
- **ERB tags in `config/ruby_native.yml` no longer break `ruby_native deploy`.** The CLI renders the file the same way Rails does.
- **`ruby_native login` always prints the authorization URL**, so you can sign in over SSH or in a container with no browser. The wait for authorization also survives network blips and reports what the server returned when something else goes wrong.
- **`ruby_native preview` explains a failed tunnel**, with cloudflared's exit status and last output, instead of hanging or exiting silently. It also tells you when `config/ruby_native.yml` is missing or empty rather than reporting the tunnel ready.
- **Deploying to a deleted or archived app no longer dead-ends.** The error points to the dashboard first and only suggests re-linking if you meant to switch apps, and a build that disappears mid-deploy stops the wait with a clear message instead of polling silently for 10 minutes.
- **Typos fail fast.** Unknown commands and unknown `--platform=` values exit with an error instead of quietly building iOS, and `ruby_native` usage now lists every flag.
- **A missing `config/ruby_native.yml` now returns a real error from `/native/config.json`** instead of `null`, so apps show a setup message instead of a confusing parse failure.
- **The CLI works in containers without a home directory** when `RUBY_NATIVE_TOKEN` is set.
- **The branded navbar no longer flickers while pushing a screen.** It dropped to a plain white title bar mid-push before snapping back. Advanced Mode, Android only.
- **Pushing a screen now slides, like iOS, instead of cross-fading when the navbar is branded.** The whole screen used to wash out mid-transition. Advanced Mode, Android only.

## [0.13.0] - 2026-08-12

### Added

- **`ruby_native preview` now takes its port from `PORT` when that is set**, matching `rails server`. `--port` still wins, and an unusable `PORT` falls back to 3000. Thanks, [@jnstq](https://github.com/jnstq)!
- **Taps feel native out of the box.** In the app, the web view's gray tap flash is gone, long-pressing a button no longer selects its label, and double-tap zoom is off on links, buttons, and form controls. Pressed states you style with `:active` now apply instantly on touch instead of after a long hold. Both platforms, both modes.
- **The User-Agent now reports the app's version, build number, and OS version**, like `Ruby Native iOS/5.2/35 iOS/26.5.2 RubyNative/0.12.5`. New helpers read them: `native_app_version`, `native_app_build`, and `native_os_version`. Each is `nil` on the web; build and OS are also `nil` in apps built before this release. Both platforms, both modes. [Docs](https://rubynative.com/docs/setup)
- **`RubyNative.toast()` accepts per-platform icons**, like the helper always has: `RubyNative.toast({ message: "Shared.", icons: { ios: "square.and.arrow.up", android: "share" } })`. Both platforms, both modes.
- **Linked domains now work on Android: links and QR codes to your site open the app, and saved website passwords fill in the app.** Add the `android` section to `config/ruby_native.yml` and ship a build after this release. [Docs](https://rubynative.com/docs/linked-domains)
- **Link only part of your domain with `linked_paths`.** List path prefixes in `config/ruby_native.yml` and only those URLs open the app; everything else keeps opening in the browser. Both platforms. [Docs](https://rubynative.com/docs/linked-domains)
- **New CSS variables keep fixed overlays out of the status bar.** Banners, toasts, and modal headers anchored with `top:` can use `--ruby-native-safe-area-top` (and `-bottom`) in a `max()` expression to clear the notch on iOS and the status bar on Android, where raw `env(safe-area-inset-*)` silently returns 0. Both platforms, both modes. [Docs](https://rubynative.com/docs/appearance)

### Fixed

- **`rails generate ruby_native:install` now works in apps with a customized development config.** Apps that disable host checking with `config.hosts = nil` no longer crash on boot after installing, and apps whose development.rb uses a renamed configure block get the tunnel host added instead of silently skipped.

## [0.12.5] - 2026-08-11

### Added

- **Support tablets.** Turn it on in your app's dashboard settings and iOS builds target iPad as well as iPhone, which also lists the app on Apple Vision Pro. Required when you're replacing an App Store app that already supports iPad: Apple rejects any update that drops a device. It can't be turned off once an iPad build ships, so the dashboard locks it after. Android tablets are always included, no setting needed.

### Fixed

- **Tablets now rotate freely.** The portrait-by-default rule applies to phones only; `appearance.landscape` still controls them. Newer OS versions ignore orientation locks on large screens anyway, so locking only split behavior across older tablets. Both platforms, both modes.
- **A rejected App Store Connect upload now shows Apple's actual reason on the build page**, instead of pointing you at your API key when the key was fine.

## [0.12.4] - 2026-08-11

### Fixed

- **A modal form's redirect now renders the page it returns to.** The landing page kept its stale pre-submit content, and a flash toast on it never showed. Advanced Mode, both platforms.
- **Navbar buttons without an icon now show their title as text on Android**, matching iOS. They rendered the missing-icon placeholder before. Both modes.
- **The floating action button now carries its `rubyNative/fab` accessibility identifier**, so UI tests can address it. Advanced Mode, iOS.

## [0.12.1] - 2026-08-06

### Added

- **Native toasts.** `<%= native_toast_tag flash[:notice] %>` in your layout floats confirmations over all app chrome, including the nav bar, and navigating back never repeats one. Both platforms, both modes. [Docs](https://rubynative.com/docs/toasts), including the Inertia components.
- **`RubyNative.toast("Saved.")` shows a toast from client-side JavaScript**, no server round trip. A browser ignores the call, so it is safe to run unconditionally.

### Fixed

- **`ruby_native preview` now names the real reason your app did not serve its config.** Every failure used to blame an unmounted gem and link a docs page that does not exist, so a 500 from a pending migration sent you to re-check a mount that was already fine. A 500 now points at your app, and a redirect names where the request went.

## [0.12.0] - 2026-08-03

### Breaking

- **A leading navbar button now yields its slot to the back button.** One rule on every platform and mode: the button shows on screens with nothing to go back to, like a tab's root. If you rely on a leading button staying visible on pushed screens (previously iOS Normal Mode only), move it to `position: :trailing`. Before, iOS Normal Mode showed both, iOS Advanced Mode lost its back button behind the leading button, and Android dropped the button outside a tab root.
- **Android apps are now portrait-only by default, matching iOS.** Android previously ignored `appearance.landscape` and always rotated. If your app should rotate, set `landscape: true` and rebuild; rotation then resizes in place instead of restarting the screen.

### Added

- **Signing out or switching accounts now resets the app, clearing every tab, once you opt in with the identity tag.** Add `<%= native_identity_tag current_user&.id %>` to your layout; signing in never resets, and apps without the tag keep today's behavior. [Docs](https://rubynative.com/docs/authentication), including the Inertia setup.
- **Links to another tab's path now switch tabs on Android in Normal Mode**, matching iOS for Turbo, Inertia, and plain links.
- **The Android back button now follows your app's navigation history in Normal Mode**, skipping form pages.
- **Hiding the tab bar no longer loses the page in Advanced Mode on Android.** The iOS half shipped in 0.11.2.
- **Builds and screenshot captures now use the native code that matches your gem version.** Patch fixes still arrive automatically; a new native minor arrives when you update the gem.
- **Navbar segments now render on Android** as a Material segmented control in both modes, closing the gap with iOS for Turbo and Inertia apps.
- **Share buttons and share menu items now work on Android** in both modes, opening the system share sheet.
- **Submitting a form now refreshes the other tabs on Android** the next time you open them, so lists no longer show pre-submit data. Normal Mode; iOS already did this.
- **The navbar save button on Android now enables and disables live** as the form changes, matching iOS.
- **Re-tapping the current tab on Android now returns it to its root**, matching iOS.
- **Leading navbar buttons now render in Advanced Mode on Android**, which previously never showed them.
- **Tabs marked `eager: true` now preload on Android**, matching iOS.
- **Android apps now cold-start offline** using the last known configuration, matching iOS.
- **CSS keyed on `body.can-go-back` now activates on Android** in Normal Mode.
- **The Android error screen now names a gem/app version mismatch** with "Gem update needed" or "App update needed" and the fix, matching iOS. Demo app only.

### Changed

- **Backgrounding an Android app now pauses video, audio, and page timers**, matching iOS and saving battery.
- **Android release builds are now minified**, shrinking the APK and stripping debug logging.

### Security

- **A crafted `ruby_native login` link can no longer hand your CLI token to whoever sent it.** Update the gem and run `ruby_native login` again; an older CLI can no longer complete a sign-in, and the browser says so.
- **Restoring a purchase now grants the subscription to the account that bought it.** One paid subscription could previously be restored onto any number of other accounts.
- **A crafted native sign-in link can no longer send someone's session to another app.** Only apps using `auth.oauth_paths` were affected.

### Fixed

- **A crashed page now recovers instead of freezing or killing the app.** When the system reclaims a page's memory, iOS reloads it in place and Android rebuilds the tab; Android previously crashed outright and iOS sat on a blank page until relaunch. Normal Mode; Advanced Mode already recovered on both platforms.
- **Background tabs can no longer sign you out, flip the tab bar, or swallow a cold-launch notification tap.** Only the tab on screen steers shared state now, matching Advanced Mode. Normal Mode, iOS only.
- **Returning to a tab no longer re-fires its last action on Android.** A cross-tab link could bounce the tab straight back, and a completed scan could reopen the camera. Normal Mode, Android only.
- **The Android splash screen no longer hangs on a first page that fails to load.** It gives way after ten seconds, matching iOS.
- **Fast navigation can no longer mark the wrong page as a form page**, which quietly made the back button skip it for the rest of the session. The same fix keeps `native_presentation_tag :root` from clearing history it shouldn't in Inertia apps. Both platforms, Normal Mode.
- **Saving a form no longer leaves a back button pointing at the submitted form.** Landing on a page whose only history is the form behind it now shows no back affordance, and on Android the back press no longer silently does nothing after a navbar-button submit. Both platforms, Normal Mode.
- **Purchase buttons no longer risk claiming in-app purchases are unavailable in a build that has them.** A script-timing race let the no-IAP fallback claim the button first; it now always yields to the real purchase flow. iOS only.
- **Turbo's cached page previews no longer report stale signals.** Badge counts and navbar state now always come from the fresh page. Both platforms.
- **Share buttons and share menu items now show the Material share glyph on Android by default.** Without `icons:` they rendered the missing-icon placeholder, since the default is an SF Symbol name.
- **Tapping a link while a page is still loading no longer shows an error screen.** Normal Mode, iOS only.
- **The QR code generated by `ruby_native preview` now scans on Android.** It failed on dark terminal themes before.
- **The "Wants to Use ... to Sign In" alert now shows your app's name instead of "RubyNative".** iOS only; your next deploy picks it up.
- **`ruby_native deploy --if-needed` no longer crashes before an app's first successful build**, and `--android --if-needed` now compares against Android builds instead of iOS ones.

### Upgrade guide

1. `bundle update ruby_native`. On its own this closes both sign-in holes above and fixes which account a restore credits.
2. Run `ruby_native login` again. An existing CLI session keeps working, but new sign-ins need this version.
3. **Using in-app purchases?** Run `bin/rails generate ruby_native:iap` and then `bin/rails db:migrate`. Your `on_subscription_change` callback then fires once per purchase instead of once per restore. Skipping it is safe, and so is re-running the generator.
4. **Recommended: adopt the identity tag.** Add `<%= native_identity_tag current_user&.id %>` to your layout, outside any signed-in check, and rebuild. Skipping it is safe. Inertia apps: follow [the sign out docs](https://rubynative.com/docs/authentication).

## [0.11.2] - 2026-07-27

### Added

- **`native_presentation_tag :root` lets a page declare that it lands as a root**, with nothing behind it and no back affordance, wherever it lands. A screen that is always the first one in its tab — a dashboard reached by scanning a code, the page you land on after choosing an account — now says so about itself, instead of every link and form that reaches it having to say it. Because it is read at the destination rather than at the origin, a `POST` and its redirects carry the intent to wherever the chain actually ends, and a validation failure that re-renders the form declares nothing at all. Not the same as `action: :replace`, which swaps the current entry and leaves everything under it. In Advanced Mode it applies before the navigation commits when the page arrives from a form submission, which is the only case where the destination has been fetched by the time the screen is decided; a link tap, a deep link or a cold boot lands first and the stack is corrected once the page renders. Normal Mode applies it on every arrival. Both modes, iOS and Android. Inertia apps get the same thing as a `NativePresentation` component from `@ruby-native/react` and `@ruby-native/vue`.

- **`menu.item` accepts `action: :replace` to control how its page lands.** A navbar menu item is a link with native chrome, so it now takes the same push/replace history semantics: `:replace` swaps the current entry in place, with no back arrow and no stack growth, which is what a page switcher wants. The default stays push. Both Normal and Advanced Mode, iOS and Android. Inertia apps get it as an `action` prop on `NativeMenuItem`.
- **`navbar.button position: :title` turns the nav-bar title into a dropdown menu.** The title becomes a menu button, the native counterpart of SwiftUI's `toolbarTitleMenu`: the button's `menu` items switch the current view and the title shows the selected one with a checkmark, defaulting to that item's label. Pair it with `action: :replace` for a page switcher. Both Normal and Advanced Mode, iOS and Android. Inertia apps pass `position="title"` to `NativeButton`.

- **`NativeSegment` brings navbar segments to Inertia apps.** The React and Vue counterpart of `navbar.segment`, with the same `title`, `href`, `click`, and `selected` props. iOS only, as segments already were.

### Fixed

- **A query string no longer stops a `/new` or `/edit` screen from presenting as a sheet in Advanced Mode.** Path configuration patterns are matched against the path and the query string joined together, on both platforms, so the anchored `/new$` rule missed `/orders/new?kind=draft` and the screen pushed instead of coming up modally. Nothing about the rule says that, and a filtered or prefilled Rails form is ordinary, so the rules now tolerate a trailing query. Paths that merely contain the word, like `/news?page=2`, are still pushed. Both platforms.
- **`native_tabs_tag enabled: false` no longer throws away the page in Advanced Mode.** Any page without a tabs element rebuilt the navigator at the entry point, which is right for the sign-out wall it was written for and wrong for a detail screen that just wants the bar out of the way, so tapping into a record landed the user back on the first tab. The two are now told apart by where the page arrives: a modal restarts, a push hides the bar in place and keeps its stack, and a background tab is ignored. Popping brings the bar back. iOS only.
- **Signing out of an Advanced Mode app no longer lands on `/`.** Hiding the tab bar rebuilt the app's single navigator at the bare base URL rather than the entry point a cold launch uses, so an app whose `/` is a marketing site or a redirect dropped the user there instead of on its first screen. It now starts at `app.entry_path`, or the first tab's path when that is unset, which is what launch already did and what Android already does by resetting each tab to its own start URL. iOS only.
- **Overscroll no longer rubber-bands to white in Advanced Mode.** Its web view was left opaque, so WKWebView painted its own white background across the whole scroll extent and covered whatever the page set on `html`, including the gap the pull-to-refresh spinner opens. `native_overscroll_tag` and `appearance.background_color` now both reach the overscroll area, as Normal Mode has done since 0.5.0. That is the release that introduced the helper, so it has never worked in Advanced Mode until now. iOS only.
- **Tab badge counts now reach VoiceOver on iOS.** iOS 26 draws the badge but puts nothing in the accessibility tree for it, so the count was invisible to anything not reading pixels. It is published as the tab's accessibility value now, matching what Android already reported. iOS only.
- **The Advanced Mode navbar menu button now renders its configured icon, tinted to the navbar's foreground color.** It drew a hardcoded, untinted overflow icon that ignored `icon:` and `icons:`, so a branded bar showed no visible glyph; the toolbar's submit button and FAB are themed to match now too. An iOS-only name like `ellipsis.circle` renders the missing-icon placeholder on Android instead of a coincidental overflow dot, so give menu buttons `icons: { android: ... }`. Android only.
- **A navbar menu button with no icon falls back to the overflow glyph instead of the missing-icon placeholder.** Both Normal and Advanced Mode, Android.
- **The Android splash screen shows the customer's icon, not the bundled Ruby Native logo.** The per-app icon was written as a mipmap that couldn't override the splash's drawable resource, so a flavor-level `splash_icon.xml` now points the splash at it. Android only.
- **A scan on an Android emulator reports `unsupported` instead of hanging.** An emulator declares a camera and grants the permission, but its virtual scene can never resolve a barcode, so the viewfinder opened and sat there with no way for the page to know. It now settles as `unsupported`, the same outcome as a device with no camera, which reveals your manual-entry fallback. Simulator already did this on iOS. Android only.

## [0.11.1] - 2026-07-21

### Fixed

- **`icons:` now raises when given something other than a hash, instead of silently rendering no icon.** Square brackets in ERB produce an array holding one hash, which skipped the per-platform lookup and left the button with no icon on either platform and nothing explaining why. Affects `navbar.button`, `menu.item`, `share_button`, `share_item`, and `native_fab_tag`.
- **`icons:` now works on its own, without a matching `icon:` alongside it.** A browser has no platform, so nothing matched and the value came back nil, which raised on `native_fab_tag` and returned a 500 for a page that rendered fine inside the app. It falls back to `icon:` and then to any name in `icons:`, the order the YAML config already uses for tabs.

## [0.11.0] - 2026-07-21

### Added

- **Scan barcodes and QR codes with `native_scan_button_tag`.** Renders a button that opens the native camera scanner; a successful scan fills a target field and fires a `ruby-native:scan` CustomEvent, so the same call works in plain Rails, Turbo, and Inertia. iOS and Android.

### Fixed

- **`window.alert`, `confirm`, and `prompt` now show native dialogs on Android.** They previously did nothing, and `confirm()` / `prompt()` resolved to their cancelled value, so a page that worked in a browser silently misbehaved. Both Normal and Advanced Mode.
- **Navbar, FAB, and tab signals now survive navigation in Advanced Mode.** `addJavascriptInterface` only binds on a real page load, so the bridge went quiet after the first navigation and native chrome stopped updating. Android only.
- **Links to a path another tab owns now select that tab in Advanced Mode.** They pushed onto the current tab's stack instead, because the Hotwire navigator has no tab awareness. Normal Mode already did this. Android only.
- **The Advanced Mode FAB renders in the right place and responds to taps.** It was added to a root that isn't a `FrameLayout`, so its gravity was ignored and it drew top-left underneath the WebView, which is also why taps did nothing. It now survives a back-pop or tab switch too. Android only.
- **Advanced Mode no longer crashes when a FAB or navbar button uses a relative href.** Tapping a control whose `href` is a path like `/books/new` killed the app, because a location is parsed as a full URL before routing; relative hrefs now resolve against the app's start URL, the way deep links already did. Android only.
- **The Advanced Mode sign-in wall now presents as a modal, matching iOS.** Sign-in paths were re-declared as a plain root screen, so sign-up and password-reset stacked a second modal on top instead of pushing inside the existing one, and any auth path that rule didn't name was missed. The whole auth flow is now one modal with internal push navigation. Android only.
- **Tapping a non-active tab no longer bounces back to the first tab.** In an Inertia or Turbo app the `[data-native-tabs]` element briefly leaves the DOM during a client-side swap, which read as a sign-out and reset every tab. Normal Mode, Android.
- **Detail and form pages no longer reset every tab.** Only a completely signal-less page now arms the unauthenticated reset; before, any back navigation or form redirect onto a tabbed page looked like a fresh sign-in. Normal Mode, Android.
- **Web content follows system dark mode on Android.** The static light theme pinned `prefers-color-scheme` to light on every page. Normal Mode.
- **Pull-to-refresh works again in Normal Mode on Android.** Compose's `PullToRefreshBox` is nested-scroll driven and a WebView never dispatches nested scroll, so the WebView now rides in a `SwipeRefreshLayout`, the same mechanism Advanced Mode uses.
- **Tab badge counts now reach TalkBack.** `NavigationBarItem` silences the badge's own text node, so the count is exposed on the badged item's content description instead. Android only.
- **A page with an empty `<title>` no longer shows its URL in the Advanced Mode toolbar.** `WebView.getTitle()` falls back to the scheme-stripped URL and Hotwire feeds that into the toolbar; iOS already left an empty title empty. Android only.
- **Advanced Mode no longer crashes on launch when a layout view is missing.** Unguarded `findViewById` dereferences threw an uncaught NPE and crash-looped the activity. Android only.
- **Malformed bridge payloads and hostile config values no longer crash the app.** An adversarial unit-test sweep across both packages found and fixed several, including a remote crash vector where the Android signal parser caught only `SerializationException` while kotlinx's JSON casts throw others.
- **Screenshot captures report an incomplete run as a failure instead of a success.** A run that captured only some paths reported success and quietly delivered a partial set. Captures now retry a path that fails, notice a crashed app in seconds rather than waiting out the full timeout, and say plainly when screenshots are still missing.
- **Signing back in no longer leaves the first tab blank under a set title.** The auth reset reloaded every tab, including the one that had just rendered the signed-in page; that WebView now becomes the first tab as-is and only sibling tabs reload, matching iOS. Normal Mode, Android.
- **Standalone navbar buttons now render in Advanced Mode.** Only dropdown menus and the submit button made it into the toolbar, so a plain icon button like the barcode scan button was silently dropped. Android only.
- **The FAB's shadow fades out instead of cutting off in a hard line.** The shadow drew past its host view's bounds and clipped; the button's standoff now leaves room for it. Advanced Mode, Android.
- **The Android config error screen now matches iOS.** Retry re-fetches the config, the demo app adds a Change servers escape hatch and a View error details dialog with gem and app versions and copyable output, and a customer's shipped app shows only generic end-user copy instead of raw config detail.
- **The Android demo app shows the Ruby Native version, not its own build number.** The welcome screen displayed the internal versionName; it now shows the library version like iOS, and the launcher shortcut says "Switch website" to match.
- **An icon name that doesn't resolve now shows a placeholder instead of a blank button on iOS.** A name that isn't an SF Symbol on the running device rendered nothing at all, and a button with no title disappeared entirely, so a typo could silently delete a working action. Android already fell back to a visible glyph. iOS only.
- **The missing-icon placeholder reads more clearly as a broken icon on Android.** A plain question mark in a tab or nav bar looks like a deliberate help affordance; it's now a bracketed question mark, matching the intent of the iOS placeholder. Android only.

## [0.10.22] - 2026-07-17

### Fixed

- **Advanced Mode now opens every OAuth sign-in in the native sign-in session.** A provider link rendered as a `button_to` with `data-turbo="false"` (the usual OmniAuth shape, since it only accepts POST) or reached through a server-side redirect loaded inside the web view instead of `ASWebAuthenticationSession`. This also unblocks providers that check for a managed device, like Microsoft Entra Conditional Access, because Microsoft's SSO plug-in only attaches to the native session. Normal Mode already handled both. iOS only.
- **An OAuth path that sits under a tab's path now signs in instead of switching tabs in Advanced Mode.** Tab routing matched first and swallowed the sign-in. iOS only.

## [0.10.20] - 2026-07-14

### Added

- **`@ruby-native/react` and `@ruby-native/vue` now ship TypeScript declarations.** Importing a component gives you autocomplete and prop checking with no `@types` package to install; `NativeIcons`, `NativeButtonPosition`, and `NativeHapticFeedback` are exported as types. The declarations are generated from the package source at publish, so they can't drift from the components.
- **Pop the navigation stack from React and Vue with `NativeBackButton`.** The counterpart of `native_back_button_tag`: renders a chevron unless given children, and forwards extra props to the underlying button.
- **Check the current platform from React and Vue with `nativePlatform()`.** Returns `"ios"`, `"android"`, or `null` on the web, matching the `native_platform` Rails helper.
- **File links now open in-app in QuickLook instead of ejecting to a logged-out browser.** A PDF, image, or other attachment opened by a link tap or `window.open` used to open a session-less browser showing a login screen; it now downloads with the app's session and previews in QuickLook. Covers link taps and `window.open` in Normal Mode and `window.open` in Advanced Mode. iOS only.

### Fixed

- **Normal Mode no longer crashes on popups that open a non-web URL.** A `window.open` targeting a `mailto:`, `tel:`, or auth-provider scheme (like a Sign in with Apple popup) crashed the app because the in-app browser rejects non-http(s) URLs; these now hand off to the system handler while web URLs still open in the in-app browser. iOS only.

## [0.10.14] - 2026-07-03

### Added

- **Configure how push finds the signed-in user with `RubyNative.current_user_resolver`.** Defaults to `current_user`; set it to a method name or a callable like `-> { Current.person }` so apps that expose the current user another way don't need a `current_user` alias just for push.

### Changed

- **Inline navbars now read with `<%=` in ERB.** The `navbar` and `menu` builder methods return a blank string, so `<%= navbar.button %>` renders nothing extra and passes `erb_lint`, which flags a bare `<%` call as an unused expression. Existing `<%` usage still works.

### Fixed

- **Microphone capture now actually starts on Android.** `getUserMedia` cleared the permission but failed with `NotReadableError` because the app didn't declare `MODIFY_AUDIO_SETTINGS`, which Chromium's WebView needs to open the audio device. Apps that opt into the microphone now declare it. Applies to both Normal and Advanced Mode.
- **The file-input camera option now works in Advanced Mode on Android.** Tapping Camera in a file picker silently did nothing because the app declared `CAMERA` but never requested it at runtime; the picker now requests the camera permission first, matching the `getUserMedia` flow.

## [0.10.12] - 2026-07-02

### Added

- **Add segments to the navigation bar with `navbar.segment`.** Render up to a few segmented buttons in the bar to switch between closely related pages (iOS only for now); mark the current page's segment `selected`. Switching segments replaces history instead of stacking it, so the back button doesn't step through the switches.

### Fixed

- **Microphone and camera capture now work in Advanced Mode on Android.** Web `getUserMedia` requests were silently denied with no permission prompt; they now request the native runtime permission and grant the web view, matching Normal Mode and iOS.
- **`native_version` now reports the real version in Android apps.** The Android User-Agent hardcoded the version, so the helper always returned `0.1.0`; it now reflects the installed build, matching iOS.
- **Advanced Mode tab bar no longer has extra padding below it on Android.** The gesture inset was applied twice, leaving an empty band beneath the tab labels; it now sits flush against the gesture bar, matching Normal Mode.

## [0.10.11] - 2026-06-26

### Added

- **Add a launch splash screen on iOS with `appearance.splash`.** Set `enabled: true` to show your launch icon and `background_color` with an activity indicator until the first screen loads, instead of flashing to a blank web view.

## [0.10.10] - 2026-06-26

### Added

- **Brand the navigation bar with `appearance.navbar`.** Set a centered `logo`, bar `background_color`/`foreground_color`, and a `status_bar` style (`light`/`dark`) to brand the bar across the whole app; the logo replaces the page title on every screen.
- **`config/ruby_native.yml` is now evaluated as ERB.** Interpolate Rails helpers into your config, most usefully `logo: "<%= image_url('logo.png') %>"` so the navbar logo points at a fingerprinted asset the app downloads once and caches.

### Fixed

- **Advanced Mode tab bar icons now render on Android.** Configured Material Symbols (`icons.android`) previously fell back to a blank placeholder for all but a few names; each tab now draws its icon, matching Normal Mode and iOS.

### Changed

- **Tab labels now always show in Advanced Mode on Android.** With four or more tabs, Android hid the label on unselected tabs; every tab now shows its title, matching iOS and Normal Mode.

## [0.10.9] - 2026-06-25

### Added

- **`navbar.share_button` adds a native share button to the nav bar.** Tapping it opens the iOS share sheet for the current page, or a custom `url:`.

### Fixed

- **Muted background videos no longer force fullscreen on iOS.** Web views now enable `allowsInlineMediaPlayback`, so `playsinline` video plays inline in both Normal and Advanced Mode.
- **`[data-native-app]` is now reliably set on Android in Normal Mode.** The marker applies at document start, matching iOS, so CSS keyed to it (like `.native-hidden` and the safe-area inset fallbacks) takes effect.
- **Microphone and camera capture (`getUserMedia`) now works on Android.** Media requests bridge to a native runtime permission instead of being silently denied, matching iOS; opt in per app with the usage descriptions in your app settings.

## [0.10.8] - 2026-06-22

### Added

- **The native error and offline screens are now customizable and localized.** Set per-state icons (`offline` for no connectivity, `generic` for any other load failure) in `config/ruby_native.yml` under `errors:`, using the same `icon:`/`icons:` form as tabs, and put title, message, and shared retry copy in your app's own locale files under the `ruby_native.errors.*` namespace.

## [0.10.6] - 2026-06-16

### Fixed

- **The floating action button and native nav bar now render in apps without a tab bar.** When `config/ruby_native.yml` had no `tabs:` section, the iOS bridge only reported native signals on pages that declared a tab bar, so a tab-less app's FAB and nav bar never appeared. The bridge now reports whenever any native signal is present (FAB, nav bar, form, or push), and the Normal Mode FAB anchors to the bottom safe area when there is no tab bar to sit above.
- **A presented modal no longer removes the Advanced Mode FAB.** Opening a modal (a `/new` or `/edit` screen) whose page declared no FAB tore down the underlying tab's FAB, and dismissing the modal did not bring it back.

## [0.10.4] - 2026-06-12

### Changed

- **Relaxed the `jwt` dependency to `>= 2.0, < 4`** so apps on jwt 3 (for example, anything using Intercom's JWT helper) can install the gem. The previous `~> 2.0` pin forced a resolution conflict. The Apple IAP webhook decoder now passes `algorithms: ["ES256"]`, which behaves identically on jwt 2 and 3.

### Fixed

- **The native tab bar no longer resets to the first tab during SPA navigation.** Inertia and Turbo briefly drop the `data-native-tabs` element on each page change; the iOS Normal Mode runtime now debounces the signal to ignore the transient drop.
- **The floating action button (`native_fab_tag`) now follows the visible tab.** In tab-based apps it could vanish when you returned to its tab and then stick on every tab after a pull-to-refresh, in both Advanced and Normal Mode.
- **The Advanced Mode navbar submit button keeps its enabled state after a form submit in another tab.** A background tab reloading could repoint the `navbar.submit_button` disabled toggle and leave the visible form's button stuck.

## [0.10.3] - 2026-06-06

### Fixed

- **Advanced Mode navbar buttons now appear on the first paint after a modal dismisses.** When a modal's form redirected to a new screen, the destination's buttons were dropped until a manual pull-to-refresh because the view controller wasn't on screen when the signal arrived. The navbar now retries briefly until the screen settles.
- **OAuth callback paths in `auth.oauth_paths` no longer trip a native sign-in loop.** Listing a provider's callback next to its authorize path made the iOS app treat the callback as a sign-in entry point and loop. The gem now drops any callback that duplicates a listed authorize path and warns; list only authorize paths.

## [0.10.2] - 2026-06-01

### Added

- **The config error screen now flags gem/native version mismatches** and shows the fix: the `bundle update ruby_native` command for an old gem, or an **Update app** button for a stale app. When versions match, it names the offending `config/ruby_native.yml` key.

### Changed

- **Config errors no longer leak developer detail to end users.** Shipped apps show a generic message; the Preview app adds a **Change servers** button and shows the unreachable server URL.

### Fixed

- **Tabs that use only `icons:` now keep working on older native binaries.** When a tab defines the per-platform `icons: { ios:, android: }` form without a flat `icon:`, the served config now also populates the legacy `icon` field from `icons.ios` (falling back to `icons.android`). Native binaries that predate the `icons:` option read only `tab.icon`, so without this they showed no tab icon. An explicit `icon:` is always preserved.

## [0.10.0] - 2026-05-25

### Added

- **Pull-to-refresh on pages with a native navbar.** Any page that renders `native_navbar_tag` now reloads when the user pulls down from the top, on both iOS and Android Normal Mode. The reload uses the current URL, which means Turbo and Inertia pages refresh correctly without any extra work. Pass `pull_to_refresh: false` to `native_navbar_tag` on a specific page to opt out. Advanced Mode already supported pull-to-refresh through Hotwire Native, so no change is needed there.
- **Linked domains for iOS.** Tapping a link to your site now opens the app instead of Safari, and saved passwords from your site autofill in the app's web views. Opt-in by adding `ios.bundle_id` and `ios.team_id` to `config/ruby_native.yml`; the gem then serves `/.well-known/apple-app-site-association` automatically and the build pipeline includes the entitlement in every iOS build. See [Linked domains](https://rubynative.com/docs/linked-domains).

### Changed

- **Install generator template** revamped with a uniform documentation style. Every field now has a block comment above it describing what it does, listing the options with their meanings, and noting the default. Existing apps are unaffected; only `rails generate ruby_native:install` output changes.

### Removed

- **`app.name` default.** `RubyNative.config[:app][:name]` no longer falls back to `"Ruby Native"` when missing from the YAML — the value was never read anywhere. If you somehow relied on the default, set the key explicitly.

## [0.9.4] - 2026-05-20

### Added

- **`ruby_native preview --url URL`** points the cloudflared tunnel at an arbitrary upstream instead of `http://localhost:PORT`. Useful when your Rails app runs behind a docker compose entry point that isn't directly reachable from a phone.

## [0.9.3] - 2026-05-17

### Added

- **In-app review prompts.** New `native_review_tag` helper (and `NativeReview` component for React and Vue) asks iOS to show the [App Store rating prompt](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews) when the page loads. Apple throttles when it actually appears, so it is safe to render anywhere; it is also suppressed during screenshot runs.

## [0.9.2] - 2026-05-17

### Added

- **`icons:` option for per-platform icon names.** Pass `icons: { ios:, android: }` alongside the existing `icon:` string on navbar buttons, menu items, FABs, and tabs to use platform-specific icon identifiers. Resolves via the native platform parsed from the Ruby Native UA, falling back to `icon:` when the platform-specific value is missing. Available in the ERB helpers, the React package, and the Vue package. Motivated by Android needing Material Symbols names (e.g. `coffee`, `shopping_bag`) instead of the SF Symbols identifiers (`cup.and.saucer`, `bag`) that work on iOS. Additive: existing configs using `icon:` keep working unchanged.
- **`ruby_native deploy --android` triggers an Android cloud build instead of iOS.** Polling and success messaging adapt to Play Internal Testing. Pass `--platform=ios|android|all` for explicit control; default behavior is unchanged.

### Fixed

- **Rails 8.1 compatibility for the gem's middleware initializers.** Rails 8.1 replaced the initializer array with a sorted graph, which could place `ruby_native.oauth_middleware` and `ruby_native.tunnel_cookie_middleware` after the middleware stack was already frozen. That broke the host app entirely, including `bin/rails middleware` and every generator. Both initializers now run `before: :build_middleware_stack` so they are ordered correctly. No config changes needed.

## [0.9.1] - 2026-05-12

### Fixed

- **`screenshot_sign_in` lambda now receives a helper object instead of the raw controller.** In Rails 8.1, `cookies` is private on `ActionController::Base`, so the previous `controller.cookies.signed.permanent[...] = ...` pattern raised `NoMethodError` and `/native/screenshots/session` returned 500. The lambda is now yielded a small helper exposing public `cookies`, `request`, and `session` accessors. **Breaking-but-allowed:** update your initializer's lambda parameter to a name like `helper` and call `helper.cookies` / `helper.request` / `helper.session` instead of `controller.cookies` etc. The 0.9.0 API had no production users to migrate.

## [0.9.0] - 2026-05-05

### Added

- **Authenticated App Store screenshots from a real iOS Simulator.** Generate a per-app screenshot key on the Ruby Native dashboard, register a `screenshot_sign_in` lambda in your initializer, and Ruby Native captures App Store screenshots against your deployed site, signed in as a designated user.
- **`RubyNative.configure` block.** Set `c.screenshot_key` and `c.screenshot_sign_in` for the screenshot session endpoint.
- **`GET /native/screenshots/session` endpoint** mounted by the gem engine. Validates the screenshot key, calls the configured sign-in lambda, and sets a session-scoped cookie.
- **`ruby_native_screenshot_session?` view helper.** Returns true when the current request is part of a screenshot run, so views can render deterministically (frozen timestamps, hidden push banners, suppressed analytics).

### Removed

- **`ruby_native screenshots` CLI command.** Screenshots are now captured by Ruby Native's CI infrastructure, not by a local Playwright run. Calling the old command after upgrading prints a deprecation message and exits non-zero.

## [0.8.2] - 2026-04-29

### Added

- **`native_fab_tag` floating action button signal.** Renders a native floating button above the tab bar. Accepts `icon:` (SF Symbols name, required), `href:` (URL to visit), and `click:` (CSS selector to click). Shows/hides per page based on signal presence. Works in both Normal and Advanced Mode. iOS 26+ renders with Liquid Glass styling, older versions use a bordered button.
- **`NativeFab` component for React and Vue.** Same API as the ERB helper: `icon`, `href`, and `click` props.

### Fixed

- `TunnelCookieMiddleware` no longer joins multi-cookie responses with `"\n"`. Under Rack 3 this caused browsers to drop every cookie after the first, breaking login through the Cloudflare tunnel preview. Multi-cookie responses now return an `Array` of `Set-Cookie` strings, matching Rack 3's contract.

## [0.8.1] - 2026-04-22

### Fixed

- Tab routing no longer cancels navigation from an unclaimed URL back to a tab's claimed URL in Normal Mode. Under Turbo this could lock up the tab bar; under Inertia the page silently failed to navigate. See [#50](https://github.com/ruby-native/gem/issues/50) for details.

## [0.8.0] - 2026-04-21

### Added

- `ruby_native deploy --if-needed` skips the build when the gem version matches the last successful build. Designed for CI: add it as a post-deploy step and it's a no-op until you bump the gem. Triggers the build and exits immediately without polling.
- `RUBY_NATIVE_TOKEN` environment variable for CLI authentication in CI. Takes priority over the stored credentials file. Generate a token with `ruby_native login` locally, then set it as a CI secret.
- Build failure email notifications. When a build fails, the account owner receives an email with the error details and a link to the builds page.

### Fixed

- **Tab auto-routing with trailing-slash patterns no longer breaks Normal Mode navigation.** Routes like `/breweries/` now correctly match the bare path `/breweries`, preventing an infinite routing loop when Turbo.js is present.
- **Tab path matching now groups routes by tab index.** `_tabPaths` is an array of arrays instead of a flat array, so multiple auto-route patterns on the same tab are correctly identified as the same tab.

### Breaking

- **Add `viewport-fit=cover` to your viewport meta tag.** The native bridge no longer injects it automatically. Inject-after-the-fact was unreliable when the page already had a viewport meta tag, because WebKit can resolve safe area insets before the JS runs, leaving `env(safe-area-inset-*)` at `0` and breaking `native-inset`. Update your layout:

  ```erb
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  ```

## [0.7.0] - 2026-04-10

### Breaking

- **Advanced Mode no longer uses bridge components.** The `@hotwired/hotwire-native-bridge` JavaScript dependency, the `ruby_native/bridge` Stimulus controllers, and the per-feature Swift `BridgeComponent` classes are all removed. Advanced Mode now reads signal elements (`data-native-*`) via the same `RubyNative.js` bridge that Normal Mode already uses. One code path for both modes, significantly less surface area to maintain.
- **Removed deprecated helpers that only emitted the bridge Stimulus markup.** If you were still calling any of these, migrate to the signal-based equivalents:
  - `native_button_tag`, `native_menu_tag` → use `native_navbar_tag` with nested `navbar.button(...)` and `navbar.button do |button| button.item(...) end`.
  - `native_form_data`, `native_submit_data` → use `native_form_tag` plus `navbar.submit_button` inside a `native_navbar_tag`.
  - `native_search_tag` → no signal-based replacement yet; reach out if you need it.
- **Helpers now emit only signal markup.** `native_tabs_tag`, `native_push_tag`, `native_badge_tag`, and `native_haptic_data` previously emitted both `data-native-*` and the redundant `data-controller="bridge--*"` attributes. They no longer emit the bridge half, which removes some DOM noise but means any code that relied on observing those Stimulus controllers will stop firing.
- **`navbar.button` takes title as its first positional argument.** The old `title:` kwarg form no longer works. Update nested navbar buttons from `navbar.button title: "Sign out", icon: "..."` to `navbar.button "Sign out", icon: "..."`. Applies to both the ERB helper and the equivalent usage in React/Vue (which already used positional-style props).

### Added

- **`native_navbar_tag` now accepts no title.** Calling `native_navbar_tag do |navbar| navbar.button(...) end` without a title string is valid. In Advanced Mode, the destination keeps whatever title Hotwire Native derived from the HTML `<title>` tag. When a title IS provided, the shared `RubyNative.js` bridge also syncs `document.title` so Hotwire's own title observer can't race into the wrong value.
- **Bar buttons with both title and image keep the title for accessibility.** If you set both `title:` and `icon:` on a `navbar.button`, the native bar button shows the SF Symbol visually and uses the title as the VoiceOver label automatically. The Swift side builds these via `UIBarButtonItem(title:image:primaryAction:menu:)` so UIKit handles the accessibility wiring.
- **`@ruby-native/react` and `@ruby-native/vue` `NativeNavbar` `title` prop is optional.** `<NativeNavbar>{children}</NativeNavbar>` works without a title for Inertia apps, mirroring the ERB helper's behavior.

### Upgrade guide

1. Remove `@hotwired/hotwire-native-bridge` from your JavaScript dependencies and delete the `import "ruby_native/bridge"` line from your entrypoint.
2. If you have Advanced Mode pages still using `native_button_tag`, `native_menu_tag`, `native_form_data`, or `native_submit_data`, migrate them to `native_navbar_tag` with nested signals (see the [Advanced Mode guide](/docs/advanced-mode)).
3. Update any `navbar.button title: "..."` call sites to pass the title positionally: `navbar.button "...", icon: "..."`.
4. Rebuild your Ruby Native iOS app against gem 0.7.0 (or use the cloud build pipeline to regenerate it).

## [0.6.0] - 2026-04-10

### Breaking

- **Scoped npm packages.** The unscoped `ruby-native` npm package is replaced with two scoped packages published under the Ruby Native org: `@ruby-native/react` and `@ruby-native/vue`. Update your imports:
  - `import { NativeTabs } from "ruby-native/react"` → `import { NativeTabs } from "@ruby-native/react"`
  - `import { NativeTabs } from "ruby-native/vue"` → `import { NativeTabs } from "@ruby-native/vue"`
  - In `package.json`, replace `"ruby-native": "..."` with `"@ruby-native/react": "^0.6.0"` or `"@ruby-native/vue": "^0.6.0"` depending on your framework.

### Fixed

- React and Vue Inertia components now build cleanly in Vite consumers. The `@inertiajs/*` router is imported dynamically (silently skipped when Inertia isn't installed), and `react` / `vue` are no longer marked optional in `peerDependenciesMeta` (only `@inertiajs/react` and `@inertiajs/vue3` remain optional). Previously, Vite's optional-peer-dep shim broke the components' static imports.

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
