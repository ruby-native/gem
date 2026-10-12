require "ruby_native/cli/mcp/platform"

module RubyNative
  class CLI
    class Mcp
      # The one prompt this server publishes. A client with prompt support
      # shows it as a slash command (Claude Code: /mcp__ruby-native__ship);
      # anything else gets the same text from `ruby_native ship`.
      #
      # It is the whole journey in one command because `status` is the map:
      # the dashboard's rail and this prompt read the same next act and the
      # same blockers, so an agent and a person are told the same thing.
      module Prompts
        SHIP = <<~TEXT.strip
          Ship this Rails app to the App Store and Google Play with Ruby Native. Work through the
          steps below in order, one at a time. Stop whenever a step is the person's to take, tell
          them exactly what to do, and wait. After every step, say what you did and what is next.

          `status` is the map. It says where the app is and what is in the way, and it answers
          before there is an account. Read it first and again after every step, yours or the
          person's. Never say a step is done that `status` does not show as done.

          ## 1. Ruby Native is in the app

          If config/ruby_native.yml is missing: run `bundle add ruby_native`, then
          `bin/rails generate ruby_native:install`. The generator reads config/routes.rb and writes
          the config with real tab paths.

          ## 2. The first native pass

          If the layout does not yet have `stylesheet_link_tag :ruby_native`, `native_tabs_tag` and
          `native_identity_tag`, make these seven changes in this order, and stop after the
          seventh. Read https://rubynative.com/llms-full.txt first: it is the full documentation as
          plain text, with the exact helper signatures. The config is config/ruby_native.yml.

          1. Decide the mode before you change anything, because it changes step 3. Advanced Mode
             gives native push and pop transitions and a native navigation bar, and it needs Turbo
             Drive on every single page. Search the app for `data-turbo="false"`, for
             `Turbo.session.drive = false`, and for any layout or page that does not load Turbo at
             all. If you find none of those, set `app.mode: advanced` in config/ruby_native.yml. If
             you find any, leave the mode alone and tell the person exactly where they are: a page
             without Turbo renders a configuration error instead of the page.
          2. Hide the web header, footer and any web navigation from native users by adding the
             `native-hidden` class to them. Prefer that over `unless native_app?`: it is one
             template and one cached fragment for both web and native, so nothing can serve the
             wrong variant. Reach for `native_app?` only when rendering the thing at all is
             expensive or has a side effect.
          3. Opt into safe areas so content stops sitting under the status bar and the home
             indicator: `viewport-fit=cover` on the viewport meta tag and
             `stylesheet_link_tag :ruby_native` in the head. Then put `native-inset` on the content
             wrapper, or `native-inset-top` instead if you turned on Advanced Mode in step 1,
             because its navigation bar is translucent and the page scrolls underneath it.
          4. Define the tab bar under `tabs:` in config/ruby_native.yml. Read config/routes.rb
             first and use real paths. Pick two to five destinations somebody returns to, never an
             action: an index, a search or browse page, a profile or settings page. Nothing that
             404s or redirects for a signed-out user. Fewer than two tabs and the bar does not
             appear at all, so if this app really has one destination, say so and leave `tabs:`
             out. Icons are SF Symbols names on iOS and Material Symbols names on Android.
          5. Add `native_form_tag` to the body of every page that submits a form: new, edit, sign
             in, sign up, and anything else with a form on it. It marks the page so that going
             back from the success page lands on what came before the form rather than on the
             form again.
          6. Fix the two auth problems that only exist in the native app. First, native users get
             signed out at random unless the session cookie outlives the browser session: with the
             Rails authentication generator that is
             `cookies.signed.permanent[:session_id] = session.id`, and with Devise it is forcing
             remember_me on for native users. Second, render `native_identity_tag current_user&.id`
             on every page, signed out included, adapting `current_user` to whatever this app calls
             it. The app keeps screens alive between page loads, so without that tag a sign-out
             leaves the previous account's screens sitting in the other tabs. The value is hashed
             with secret_key_base and exposes nothing. The install generator prints this line too,
             so check the layout before adding a second one.
          7. Set `appearance.background_color` in config/ruby_native.yml to the exact value of the
             CSS body background, so screens stop flashing white between navigations.

          Rules for the pass: the web app has to keep working exactly as it does today, so every
          change is additive or scoped to native users. Do not add @hotwired/hotwire-native-bridge
          or any Stimulus controllers for this; Ruby Native ships its own bridge. Do not change any
          route or controller. Toasts, menus, haptics, badges, the floating action button, push
          notifications and in-app purchases are documented and none of them belong in the first
          pass.

          When you are done, run `validate_config` and `check_views` and fix what they report. Then
          tell the person to run `bundle exec ruby_native preview` and scan the code it prints with
          the Ruby Native app on their phone. Do not run preview yourself: it opens a tunnel and
          waits for a phone. List what you changed and what they should look at on the device,
          since you cannot see the app running in the native shell.

          ## 3. The account and the app

          If `status` says there is no login or no linked app, the person does two things, and you
          wait after each one:

          1. Create the app at #{Platform::HOST}/apps/new: a name and the site's URL, and an account
             if they do not have one.
          2. Run `bundle exec ruby_native login` on this machine. It opens the browser and they click
             Approve. No password goes through the terminal.

          Then call `link_app`.

          ## 4. The stores

          Read `status`. Each track, iOS and Android, has a `next` act and a `blocked_by` list. If
          neither track has started, ask which store first. Apple's enrollment is the longest wait,
          so suggest starting it now and doing the rest while it runs.

          The App Store Connect key is the one secret you handle, and only by its path: the person
          mints it in App Store Connect and downloads the .p8; you pass the path, the key ID, the
          issuer ID and the Team ID to `apple_key_set`, and never open the file.

          Take the first blocker on the track they are working:

          - `who: agent`: do it. The steps name the tool or the command. Deploys are
            `bundle exec ruby_native deploy`, which builds every started store (`--ios` or `--android` for one); run it and follow the
            build with `build_status`.
          - `who: human`: show the person the `why`, the `url` and the `steps` exactly as given,
            then stop. When they say it is done, read `status` again. A blocker with
            `verifiable: false` is a questionnaire nobody can see: it clears only on the person's
            word, on the dashboard or as a `confirmations` entry on `submit`, and only after they
            have said, in their words, that it is done.

          The listing is the person's words, so it gets a stop of its own. When a blocker asks for
          it, write `config/ruby_native_listing.yml` and save it with `listing_push`, then stop: give
          the person the blocker's `url`, where they read your draft and change
          what they like. Run `bundle exec ruby_native listing publish` only after they say it reads
          right.

          When nothing blocks the act: `build` is a deploy. When `status` carries an `update`
          with a `version`, pass it as `--version`, and do the `gem_step` first if there is one. `submit` is the `submit` tool, twice:
          the first call returns the summary and a token; show the summary, get an explicit yes,
          then call again with the token. `wait` means Apple has it and there is nothing to do.
          `release` is the person's, on the Submit page at rubynative.com. `go_live` is the person's, in Play
          Console, and `submit` with platform android prints the promotion steps.

          ## Rules

          - One step at a time. Report after each.
          - Money and secrets are the person's. Never enter card details, never paste a key or a
            password. Hand over the URL.
          - The web app keeps working exactly as it does today.
        TEXT

        LIST = [
          {
            name: "ship",
            title: "Ship this app",
            description: "Walk this Rails app to the App Store and Google Play with Ruby Native, one step at a " \
                         "time, stopping at the steps only a person can take.",
            arguments: []
          }
        ].freeze

        def self.get(name)
          return nil unless name == "ship"

          { description: LIST.first[:description], messages: [ { role: "user", content: { type: "text", text: SHIP } } ] }
        end
      end
    end
  end
end
