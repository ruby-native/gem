module RubyNative
  module Helper
    # True when the current request is part of a Ruby Native screenshot run.
    # Use this to render deterministically: freeze relative timestamps, hide
    # push banners, suppress ads, disable A/B variants, skip notifications.
    #
    #   <% if ruby_native_screenshot_session? %>
    #     Stamped 2 days ago
    #   <% else %>
    #     <%= time_ago_in_words(stamp.created_at) %>
    #   <% end %>
    def ruby_native_screenshot_session?
      cookies[:_ruby_native_screenshot_session] == "1"
    end

    def native_tabs_tag(enabled: true)
      return "".html_safe unless enabled
      tag.div(data: { native_tabs: true }, hidden: true)
    end

    def native_form_tag
      tag.div(data: { native_form: true }, hidden: true)
    end

    def native_push_tag
      tag.div(data: { native_push: true }, hidden: true)
    end

    def native_identity_tag(value)
      tag.div(data: { native_identity: native_identity_token(value) }, hidden: true)
    end

    # HMAC, not a bare digest: a digest of a small integer id space is enumerable,
    # so the DOM would effectively still carry the id it was meant to hide.
    def native_identity_token(value)
      parts = Array(value).compact
      return "" if parts.empty?
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, parts.join(":"))[0, 16]
    end

    def native_locale_tag(locale = I18n.locale)
      tag.div(data: { native_locale: locale }, hidden: true)
    end

    def native_back_button_tag(text = nil, **options)
      options[:class] = [options[:class], "native-back-button"].compact.join(" ")
      default_content = tag.svg(
        tag.path(d: "M15.75 19.5L8.25 12l7.5-7.5", stroke_linecap: "round", stroke_linejoin: "round"),
        width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: 2.5
      )
      tag.button(text || default_content, onclick: "RubyNative.postMessage({action: 'back'})", **options)
    end

    # Renders a button that opens the native barcode scanner. On a successful
    # scan the value fills `target` (a CSS selector) and the page receives a
    # `ruby-native:scan` CustomEvent (override the name with `event:`). Set
    # `submit: true` to submit the filled field's form after scanning. Narrow the
    # accepted codes with `formats:` (neutral names, e.g. "ean13,upce"); omit it
    # for a sane default. Renders a plain button on the web (no-op until opened in
    # the app); wrap in `native_app?` if it should be hidden there.
    #
    #   <%= native_scan_button_tag "Scan", target: "#isbn" %>
    #
    # The scanner needs a camera usage description set in your Ruby Native app
    # settings, or scanning is unavailable in production builds.
    def native_scan_button_tag(label = "Scan", target: nil, event: nil, submit: false, formats: nil, **options)
      if Rails.env.development?
        Rails.logger.warn(
          "[ruby_native] native_scan_button_tag needs a camera usage description set in your " \
          "Ruby Native app settings, or scanning is unavailable in production builds."
        )
      end

      scan_options = {}
      scan_options[:target] = target if target
      scan_options[:event] = event if event
      scan_options[:submit] = true if submit
      if formats
        scan_options[:formats] = Array(formats).flat_map { |f| f.to_s.split(",") }.map(&:strip).reject(&:empty?)
      end

      # A bare <button> is type="submit" inside a form, and the documented usage
      # puts this inside form_with. Without this a tap would submit the form
      # immediately and navigate away before the async scan result arrives, and
      # the `submit:` option (which is what opts into submitting) would be
      # meaningless. Callers who really want a submit button can pass
      # type: "submit" and keep it.
      options[:type] ||= "button"
      options[:onclick] = "window.RubyNative?.scan(#{scan_options.to_json})"
      tag.button(label, **options)
    end

    def native_badge_tag(count = nil, home: nil, tab: nil)
      home = count if count && home.nil?
      tab = count if count && tab.nil?

      data = { native_badge: "" }
      data[:native_badge_home] = home unless home.nil?
      data[:native_badge_tab] = tab unless tab.nil?

      tag.div(data: data, hidden: true)
    end

    # No :root. Landing a page as the tab root — dropping what is behind it —
    # is a distinct operation from replacing the current entry, and no shell
    # implements it: every one of them mapped :root onto replace, which unwinds
    # nothing. Offering the word without the behavior is worse than not
    # offering it, so it is out until a shell can honor it.
    ACTIONS = %w[push replace].freeze

    # Validates a push/replace landing value. Returns the value as a string,
    # raises otherwise.
    def self.validate_action(value, label: "action")
      value = value.to_s
      unless ACTIONS.include?(value)
        raise ArgumentError,
          "#{label} must be :push or :replace, got #{value.inspect}"
      end
      value
    end

    # The landing intents a page can declare about itself. Only :root so far.
    # :modal is the obvious second member (both shells hardcode a /new + /edit
    # rule today that no app can reach), which is why this is a vocabulary
    # rather than a boolean tag.
    PRESENTATION_INTENTS = %w[root].freeze

    # Declares that this page is a root: it lands with nothing behind it, and no
    # back affordance, wherever it lands.
    #
    #   <%= native_presentation_tag :root %>
    #
    # Emits the fact on two channels, because the shells need it at two
    # different moments and neither channel reaches both:
    #
    # 1. A `data-native-presentation` element, reported with every other signal
    #    once the page has rendered. This is what Normal Mode reads, and Normal
    #    Mode can act on it late: it has no push stack, so suppressing back is
    #    not a navigation and nothing refetches.
    #
    # 2. A `Native-Presentation` response header. Advanced Mode has to decide
    #    before the navigation commits, or it pushes and then visibly corrects
    #    itself. On a form submission Turbo has already fetched the destination
    #    by the time it proposes the visit, so the header is readable at
    #    `turbo:before-fetch-response` — before the proposal — and the header is
    #    the only part of that response readable synchronously, since the body
    #    arrives as a promise that consuming would take from Turbo.
    #
    # Nothing is declared at the origin. Both channels ride the response for the
    # page itself, so a redirect chain carries the intent to wherever it actually
    # lands rather than to wherever the link pointed.
    #
    # In Advanced Mode this takes effect before the navigation commits when the
    # page arrives from a form submission, because that is the only case where
    # Turbo has already fetched the destination by the time it proposes the
    # visit. A link tap, a deep link and a cold boot are proposed before anything
    # is fetched, so those fall back to the element and the shell corrects after
    # the page renders. Normal Mode always uses the element.
    #
    # Do not call this inside a `cache` block. On a cache hit the element comes
    # back from the cache and the header is never set, which silently leaves
    # Advanced Mode with only the slower path.
    def native_presentation_tag(presentation)
      value = presentation.to_s
      unless PRESENTATION_INTENTS.include?(value)
        raise ArgumentError,
          "native_presentation_tag must be #{PRESENTATION_INTENTS.map { |i| ":#{i}" }.join(" or ")}, " \
          "got #{value.inspect}"
      end

      # `respond_to?` rather than a nil check alone: ActionView forwards it to
      # the controller for the delegated methods, so a view rendered without one
      # answers false here instead of raising a DelegationError.
      if respond_to?(:response) && response
        if Rails.env.development? && response.committed?
          Rails.logger.warn(
            "[ruby_native] native_presentation_tag rendered after the response was committed, " \
            "so Advanced Mode will not see it before the navigation commits."
          )
        end
        response.headers["Native-Presentation"] = value
      end

      tag.div(data: { native_presentation: value }, hidden: true)
    end

    def native_navbar_tag(title = nil, pull_to_refresh: true, &block)
      builder = NavbarBuilder.new(self)
      capture(builder, &block) if block

      data = { native_navbar: title.to_s }
      data[:native_pull_to_refresh] = "false" unless pull_to_refresh
      tag.div(data: data, hidden: true) { builder.to_html }
    end

    # `color:` tints the button: tinted Liquid Glass on iOS, a colored
    # Material FAB on Android. The icon color is derived automatically to
    # stay readable against it. Pass `:tint` instead of a hex to inherit
    # `appearance.tint_color`, keeping the button in sync with the app accent.
    def native_fab_tag(icon: nil, icons: nil, href: nil, click: nil, color: nil)
      resolved = RubyNative::Helper.resolve_icon(icon: icon, icons: icons, platform: try(:native_platform))
      raise ArgumentError, "native_fab_tag requires an icon" if resolved.nil?
      data = { native_fab: true, native_icon: resolved }
      data[:native_href] = href if href
      data[:native_click] = click if click
      data[:native_color] = color if color
      tag.div(data: data, hidden: true)
    end

    # Attaches a native menu to an element already on the page. `anchor:` is a
    # CSS selector for that element; tapping it in the app opens a native menu
    # anchored to it with the block's items, and picking one navigates or
    # clicks a web element exactly like a nav bar menu item does.
    #
    #   <span id="status-pill">Want to read</span>
    #
    #   <%= native_menu_tag anchor: "#status-pill" do |menu| %>
    #     <% menu.item "Currently reading", click: "#status-reading" %>
    #     <% menu.item "Finished",          click: "#status-finished" %>
    #   <% end %>
    #
    # The anchor element stays an ordinary element on the web, so give it its
    # own web behavior (or a `native-hidden` fallback) if it needs one there.
    def native_menu_tag(anchor:, &block)
      anchor = anchor.to_s
      raise ArgumentError, "native_menu_tag requires an anchor CSS selector" if anchor.strip.empty?

      builder = NavbarMenuBuilder.new(self)
      capture(builder, &block) if block
      tag.div(data: { native_menu: "", native_anchor: anchor }, hidden: true) { builder.to_html }
    end

    def native_overscroll_tag(top:, bottom: nil)
      tag.div(data: { native_overscroll_top: top, native_overscroll_bottom: bottom || top }, hidden: true)
    end

    # Hides the iOS keyboard toolbar (the previous/next/Done bar) on this page.
    # Page-level: the toolbar belongs to the web view, not to individual fields.
    def native_keyboard_tag(toolbar: false)
      return "".html_safe if toolbar
      tag.div(data: { native_keyboard_toolbar: false }, hidden: true)
    end

    def native_haptic_data(feedback = :success, **data)
      feedback = feedback.to_s
      feedback = "success" if feedback.empty?
      data[:native_haptic] = feedback
      data
    end

    # Renders a signal element that asks the app to request an App Store
    # rating from the user. The system decides whether to actually show the
    # prompt (Apple throttles it to a few times per year), so it is safe to
    # render this on any page where a review would be welcome, like a
    # confirmation screen after the user finishes something worthwhile.
    #
    # See Apple's docs on requesting App Store reviews:
    # https://developer.apple.com/documentation/storekit/requesting-app-store-reviews
    def native_review_tag
      tag.div(data: { native_review: true }, hidden: true)
    end

    TOAST_APPEARANCES = %w[inverted system].freeze

    # Shows a transient native toast above all app chrome, including the nav
    # bar. The signal is consumed the moment it fires, so a cached page
    # restored by back navigation cannot re-toast. Renders nothing visible on
    # the web; keep your web-styled flash for browsers.
    #
    #   <%= native_toast_tag flash[:notice] %>
    #
    # A blank message renders nothing, so the flash one-liner needs no guard.
    # Icons follow the same `icon:`/`icons:` rules as the navbar; the default
    # is a per-platform checkmark and `icon: false` hides it. `appearance:` is
    # :inverted (flips the theme so the toast always pops) or :system (matches
    # it).
    def native_toast_tag(message, icon: nil, icons: nil, duration: 4, appearance: :inverted)
      return "".html_safe if message.blank?

      appearance = appearance.to_s
      unless TOAST_APPEARANCES.include?(appearance)
        raise ArgumentError,
          "appearance must be #{TOAST_APPEARANCES.map { |a| ":#{a}" }.join(" or ")}, " \
          "got #{appearance.inspect}"
      end

      # An absent icon attribute means "use the default" to the shell (the JS
      # API omits it), so `icon: false` emits an empty value to mean "none".
      platform = try(:native_platform)
      resolved = if icon == false
        ""
      else
        RubyNative::Helper.resolve_icon(icon: icon, icons: icons, platform: platform) ||
          (platform == "android" ? "check_circle" : "checkmark.circle.fill")
      end

      data = { native_toast: "", native_toast_message: message }
      data[:native_toast_icon] = resolved
      data[:native_toast_duration] = duration
      data[:native_toast_appearance] = appearance

      tag.div(data: data, hidden: true)
    end

    # Picks the right icon name for the current native platform. Accepts the
    # single `icon:` form (applied to every platform) and/or the `icons:` hash
    # form (`{ ios: "...", android: "..." }`). When both are given, a matching
    # `icons[platform]` wins; otherwise falls back to `icon`. Returns nil when
    # nothing resolves.
    #
    # A non-Hash `icons:` raises rather than falling through. `icons: [ios:
    # "...", android: "..."]` is an easy slip in ERB and yields an Array holding
    # one Hash, which used to skip the lookup and fall back to `icon` — usually
    # nil, so the button rendered with no icon on either platform and nothing
    # said why. That reads as "per-platform icons are broken" rather than "wrong
    # bracket," and it is invisible on whichever platform you aren't testing.
    def self.resolve_icon(icon: nil, icons: nil, platform: nil)
      if !icons.nil? && !icons.is_a?(Hash)
        raise ArgumentError,
          "icons: must be a Hash like { ios: \"square.and.arrow.up\", android: \"share\" }, " \
          "got #{icons.class}. Check for square brackets instead of curly braces."
      end

      if icons.is_a?(Hash) && platform
        key = platform.to_sym
        per_platform = icons[key] || icons[key.to_s]
        return per_platform if per_platform
      end

      # Nothing matched, which is every web render: `native_platform` is nil in
      # a browser. Fall back to `icon:`, then to any name in `icons:`, the same
      # order `RubyNative.backfill_tab_icons` uses for the YAML config.
      #
      # Returning nil here instead would make `icons:` alone unusable, because
      # `native_fab_tag` raises on a nil icon and would 500 a page that renders
      # fine inside the app. The signal element is hidden and only read by the
      # native app, so which name survives on the web doesn't matter.
      icon || fallback_icon(icons)
    end

    def self.fallback_icon(icons)
      return nil unless icons.is_a?(Hash)

      icons[:ios] || icons["ios"] || icons[:android] || icons["android"]
    end
    private_class_method :fallback_icon

    class NavbarBuilder
      def initialize(context)
        @context = context
        @items = []
      end

      # Adds a button to the nav bar. `position:` is :leading, :trailing (the
      # default; repeat it and the buttons sit side by side), or :title, which
      # turns the bar's title into a dropdown menu instead of adding a bar item.
      # A :title button takes a menu block and no icon or label of its own: keep
      # a title on `native_navbar_tag` and it labels the dropdown, or omit it and
      # the `selected:` item's text does.
      # https://rubynative.com/docs/navbar#title-menu
      def button(title = nil, icon: nil, icons: nil, href: nil, click: nil, position: :trailing, selected: false, &block)
        resolved = RubyNative::Helper.resolve_icon(icon: icon, icons: icons, platform: @context.try(:native_platform))
        data = { native_button: "" }
        data[:native_title] = title if title
        data[:native_icon] = resolved if resolved
        data[:native_href] = href if href
        data[:native_click] = click if click
        data[:native_position] = position.to_s
        data[:native_selected] = "" if selected

        if block
          menu = NavbarMenuBuilder.new(@context)
          @context.capture(menu, &block)
          add(@context.tag.div(data: data) { menu.to_html })
        else
          add(@context.tag.div(data: data))
        end
      end

      # Adds a segment to the nav bar. On iOS the segments render as a centered
      # segmented control (the same control the App Store uses for Apps/Games).
      # Mark the current page's segment `selected: true`. Tapping a segment
      # navigates to its `href` (or clicks the `click` selector), replacing
      # history so the back button doesn't walk back through segment switches.
      def segment(title, href: nil, click: nil, selected: false)
        data = { native_segment: "", native_title: title }
        data[:native_href] = href if href
        data[:native_click] = click if click
        data[:native_selected] = "" if selected
        add(@context.tag.div(data: data))
      end

      # Adds a native share button to the nav bar. Tapping it opens the
      # platform share sheet for `url:` (defaults to the current page on the
      # web side) so it works even where embedded web views don't support
      # `navigator.share`. Icons follow the same rules as the other navbar
      # buttons: `icon:` applies to every platform and `icons:` ({ ios:,
      # android: }) overrides per platform. Android defaults to the Material
      # `share` glyph; the SF Symbol default renders as missing there.
      def share_button(url: nil, title: "Share", icon: "square.and.arrow.up", icons: { android: "share" }, position: :trailing)
        resolved = RubyNative::Helper.resolve_icon(icon: icon, icons: icons, platform: @context.try(:native_platform))
        data = { native_button: "", native_share: "" }
        data[:native_title] = title if title
        data[:native_icon] = resolved if resolved
        data[:native_position] = position.to_s
        data[:native_share_url] = url if url
        add(@context.tag.div(data: data))
      end

      def submit_button(title: "Save", click: "[type='submit']")
        add(@context.tag.div(data: {
          native_submit_button: "",
          native_title: title,
          native_click: click
        }))
      end

      def to_html
        @context.safe_join(@items)
      end

      private

      # Collects a signal element and returns a blank, html-safe string. That
      # lets the builder read naturally with `<%=` in ERB (`<%= navbar.button %>`)
      # without emitting anything, since the nav bar renders from the collected
      # items in `to_html`, not from these return values. Silent `<% %>` tags
      # keep working too.
      def add(item)
        @items << item
        ActiveSupport::SafeBuffer.new
      end
    end

    class NavbarMenuBuilder
      def initialize(context)
        @context = context
        @items = []
      end

      def item(title, href: nil, click: nil, icon: nil, icons: nil, selected: false, action: nil, destructive: false)
        resolved = RubyNative::Helper.resolve_icon(icon: icon, icons: icons, platform: @context.try(:native_platform))
        data = { native_menu_item: "", native_title: title }
        data[:native_href] = href if href
        data[:native_click] = click if click
        data[:native_icon] = resolved if resolved
        data[:native_selected] = "" if selected
        data[:native_destructive] = "" if destructive
        data[:native_action] = RubyNative::Helper.validate_action(action) if action
        add(@context.tag.div(data: data))
      end

      # Adds a share entry to a navbar button's dropdown menu. Selecting it
      # opens the platform share sheet for `url:` (defaults to the current
      # page on the web side). Icons follow the same `icon:`/`icons:` rules
      # as the other menu items.
      def share_item(title = "Share", url: nil, icon: "square.and.arrow.up", icons: { android: "share" }, selected: false)
        resolved = RubyNative::Helper.resolve_icon(icon: icon, icons: icons, platform: @context.try(:native_platform))
        data = { native_menu_item: "", native_title: title, native_share: "" }
        data[:native_share_url] = url if url
        data[:native_icon] = resolved if resolved
        data[:native_selected] = "" if selected
        add(@context.tag.div(data: data))
      end

      def to_html
        @context.safe_join(@items)
      end

      private

      # See NavbarBuilder#add: collects the item and returns a blank, html-safe
      # string so menu items read naturally with `<%= menu.item %>` in ERB.
      def add(item)
        @items << item
        ActiveSupport::SafeBuffer.new
      end
    end
  end
end
