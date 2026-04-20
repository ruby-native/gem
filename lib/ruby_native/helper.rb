module RubyNative
  module Helper
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

    def native_back_button_tag(text = nil, **options)
      options[:class] = [options[:class], "native-back-button"].compact.join(" ")
      default_content = tag.svg(
        tag.path(d: "M15.75 19.5L8.25 12l7.5-7.5", stroke_linecap: "round", stroke_linejoin: "round"),
        width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: 2.5
      )
      tag.button(text || default_content, onclick: "RubyNative.postMessage({action: 'back'})", **options)
    end

    def native_badge_tag(count = nil, home: nil, tab: nil)
      home = count if count && home.nil?
      tab = count if count && tab.nil?

      data = { native_badge: "" }
      data[:native_badge_home] = home unless home.nil?
      data[:native_badge_tab] = tab unless tab.nil?

      tag.div(data: data, hidden: true)
    end

    def native_navbar_tag(title = nil, &block)
      builder = NavbarBuilder.new(self)
      capture(builder, &block) if block

      tag.div(data: { native_navbar: title.to_s }, hidden: true) { builder.to_html }
    end

    def native_fab_tag(icon:, href: nil, click: nil)
      data = { native_fab: true, native_icon: icon }
      data[:native_href] = href if href
      data[:native_click] = click if click
      tag.div(data: data, hidden: true)
    end

    def native_overscroll_tag(top:, bottom: nil)
      tag.div(data: { native_overscroll_top: top, native_overscroll_bottom: bottom || top }, hidden: true)
    end

    def native_haptic_data(feedback = :success, **data)
      feedback = feedback.to_s
      feedback = "success" if feedback.empty?
      data[:native_haptic] = feedback
      data
    end

    class NavbarBuilder
      def initialize(context)
        @context = context
        @items = []
      end

      def button(title = nil, icon: nil, href: nil, click: nil, position: :trailing, selected: false, &block)
        data = { native_button: "" }
        data[:native_title] = title if title
        data[:native_icon] = icon if icon
        data[:native_href] = href if href
        data[:native_click] = click if click
        data[:native_position] = position.to_s
        data[:native_selected] = "" if selected

        if block
          menu = NavbarMenuBuilder.new(@context)
          @context.capture(menu, &block)
          @items << @context.tag.div(data: data) { menu.to_html }
        else
          @items << @context.tag.div(data: data)
        end
      end

      def submit_button(title: "Save", click: "[type='submit']")
        @items << @context.tag.div(data: {
          native_submit_button: "",
          native_title: title,
          native_click: click
        })
      end

      def to_html
        @context.safe_join(@items)
      end
    end

    class NavbarMenuBuilder
      def initialize(context)
        @context = context
        @items = []
      end

      def item(title, href: nil, click: nil, icon: nil, selected: false)
        data = { native_menu_item: "", native_title: title }
        data[:native_href] = href if href
        data[:native_click] = click if click
        data[:native_icon] = icon if icon
        data[:native_selected] = "" if selected
        @items << @context.tag.div(data: data)
      end

      def to_html
        @context.safe_join(@items)
      end
    end
  end
end
