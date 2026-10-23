---
name: ruby-native
description: Turn an existing Rails app into iOS and Android apps with Ruby Native and take them to the App Store and Google Play. Use when someone asks for a mobile or native app from a Rails app, mentions Ruby Native, Hotwire Native, TestFlight, App Store review, or Google Play for a Rails product, or wants to know which store steps an agent can do and which only a person can.
---

# Ship a Rails app with Ruby Native

Ruby Native turns a Rails app into real iOS and Android apps: a native tab bar, native navigation, push notifications, and the app store work, configured from `config/ruby_native.yml` and a few view helpers. The native code is built and signed in the cloud, so nobody needs Xcode or Android Studio. The web app keeps working exactly as it does today; every change is additive or scoped to native users.

The full documentation as one file is https://rubynative.com/llms-full.txt. Read it before writing any helper or config, because it has the exact helper signatures and the config schema, and the native apps ignore anything they do not recognize without an error.

## Where you are

**In Claude Code with this plugin's MCP server connected**, `status` is the map: it says where the app is on each store's track, what is next, and what is in the way, with who clears each blocker. Read it first and again after every step. The server publishes a prompt, `/mcp__ruby-native__ship`, that walks the whole journey; prefer it over improvising. The tools `validate_config` and `check_views` check your own work without a device.

**Anywhere else**, such as claude.ai or Cowork, you cannot run the commands. Walk the person through the same steps below, tell them which command to run at each one, and have them paste the output back. The commands all start with `bundle exec ruby_native`, and `bundle exec ruby_native status` prints the same map the MCP tool returns.

## 1. Ruby Native in the app

If `config/ruby_native.yml` is missing: `bundle add ruby_native`, then `bin/rails generate ruby_native:install`. The generator reads `config/routes.rb` and writes the config with real tab paths.

## 2. The first native pass

Seven changes, in this order, and stop after the seventh.

1. Decide the mode first, because it changes step 3. Advanced Mode gives native push and pop transitions and a native navigation bar, and it needs Turbo Drive on every page. Search for `data-turbo="false"`, for `Turbo.session.drive = false`, and for any layout or page that does not load Turbo. If none, set `app.mode: advanced`. If any, leave the mode alone and say exactly where they are: a page without Turbo renders a configuration error instead of the page.
2. Hide the web header, footer, and web navigation from native users with the `native-hidden` class. Prefer that over `unless native_app?`: one template and one cached fragment for both web and native. Reach for `native_app?` only when rendering the thing at all is expensive or has a side effect.
3. Opt into safe areas: `viewport-fit=cover` on the viewport meta tag and `stylesheet_link_tag :ruby_native` in the head. Then `native-inset` on the content wrapper, or `native-inset-top` if Advanced Mode is on, because its navigation bar is translucent and the page scrolls under it.
4. Define the tab bar under `tabs:`. Read the routes first and use real paths. Two to five destinations somebody returns to, never an action: an index, a search or browse page, a profile or settings page. Nothing that 404s or redirects for a signed-out user. Fewer than two tabs and the bar does not appear. Icons are SF Symbols names on iOS and Material Symbols names on Android.
5. Add `native_form_tag` to the body of every page that submits a form: new, edit, sign in, sign up. It marks the page so going back from the success page lands before the form, not on it.
6. Fix the two auth problems that only exist in the native app. The session cookie must outlive the browser session or native users get signed out at random: with the Rails authentication generator that is `cookies.signed.permanent[:session_id] = session.id`, with Devise it is forcing remember_me on for native users. And render `native_identity_tag current_user&.id` on every page, signed out included, adapting `current_user` to this app's name for it; without it a sign-out leaves the previous account's screens in the other tabs. The value is hashed with `secret_key_base` and exposes nothing. The generator prints this line too, so check the layout before adding a second one.
7. Set `appearance.background_color` to the exact CSS body background, so screens stop flashing white between navigations.

Do not add `@hotwired/hotwire-native-bridge` or any Stimulus controller for this; Ruby Native ships its own bridge. Do not change routes or controllers. Toasts, menus, haptics, badges, the floating action button, push notifications, and in-app purchases are documented and none belong in the first pass.

Then check the work (`validate_config` and `check_views`, or `bundle exec ruby_native check`), and have the person run `bundle exec ruby_native preview` and scan the code it prints with the Ruby Native app on their phone. Never run preview yourself: it opens a tunnel and waits for a phone. List what changed and what to look at on the device.

## 3. The account and the app

If there is no login or no linked app, the person does two things, and you wait after each: create the app at https://rubynative.com/apps/new (a name and the site's URL, and an account if they have none), then run `bundle exec ruby_native login` on their machine, which opens the browser for an Approve click. No password goes through a terminal. Then link the project (`link_app`, or `bundle exec ruby_native link`).

## 4. The stores

Read `status`. Each track, iOS and Android, has a next act and a list of blockers. If neither has started, ask which store first; Apple's enrollment is the longest wait, so suggest starting it now.

Take the first blocker on the track they are working. A blocker for the agent names the tool or command: deploys are `bundle exec ruby_native deploy`. A blocker for a person gets its why, its URL, and its steps shown exactly as given, then stop; when they say it is done, read `status` again. A questionnaire nobody can see clears only on the person's word.

The listing is the person's words. Write `config/ruby_native_listing.yml`, save it with `listing_push`, and stop so they read the draft where the blocker's URL points. Publish with `bundle exec ruby_native listing publish` only after they say it reads right.

Submission is two calls: the first returns a summary and a token; show the summary, get an explicit yes, then send with the token. A mistaken submission is taken back with `withdraw`. Release is the person's, on the Submit page at rubynative.com, and promoting to production on Google Play is theirs in Play Console.

## What only a person can do

Apple: creating the app record in App Store Connect, the App Privacy questionnaire, the age rating, and the release. Google: creating the app, the App content declarations, the tester list, and promoting to production. Plus paying, the developer accounts, and the App Store Connect key, which the person mints and downloads; pass its path, never open it. Hand over the URL for each, and never enter card details, keys, or passwords.

## Rules

- One step at a time. Report after each.
- Never say a step is done that `status` does not show as done.
- Money and secrets are the person's.
- The web app keeps working exactly as it does today.
