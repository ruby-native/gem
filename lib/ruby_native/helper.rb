module RubyNative
  module Helper
    def native_tabs_tag(enabled: true)
      safe_join([
        (tag.div(data: { native_tabs: true }, hidden: true) if enabled),
        tag.div(data: { controller: "bridge--tabs", bridge__tabs_enabled_value: enabled })
      ].compact)
    end

    def native_form_tag
      tag.div(data: { native_form: true }, hidden: true)
    end

    def native_form_data(**data)
      merge_controller(data, "bridge--form")
    end

    def native_submit_data
      { bridge__form_target: "submit" }
    end

    def native_push_tag
      safe_join([
        tag.div(data: { native_push: true }, hidden: true),
        tag.div(data: { controller: "bridge--push" })
      ])
    end

    def native_back_button_tag(text = nil, **options)
      options[:class] = [options[:class], "native-back-button"].compact.join(" ")
      default_content = tag.svg(
        tag.path(d: "M15.75 19.5L8.25 12l7.5-7.5", stroke_linecap: "round", stroke_linejoin: "round"),
        width: 24, height: 24, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", stroke_width: 2.5
      )
      tag.button(text || default_content, onclick: "RubyNative.postMessage({action: 'back'})", **options)
    end

    def native_search_tag
      tag.div(data: { controller: "bridge--search" })
    end

    def native_button_tag(title, url, ios_image: nil, side: :right, **options)
      data = options.delete(:data) || {}
      data[:controller] = "bridge--button"
      data[:bridge_side] = side.to_s
      data[:bridge_ios_image] = ios_image if ios_image

      link_to title, url, **options, data: data
    end

    def native_menu_tag(title:, side: :right, &block)
      builder = MenuBuilder.new(self)
      capture(builder, &block)

      tag.div(style: "display:none", data: {
        controller: "bridge--menu",
        bridge__menu_title_value: title,
        bridge__menu_side_value: side.to_s
      }) { builder.to_html }
    end

    def native_haptic_data(feedback = :success, **data)
      feedback = feedback.to_s
      feedback = "success" if feedback.empty?

      data[:native_haptic] = feedback
      data[:bridge__haptic_feedback_value] = feedback
      merge_controller(data, "bridge--haptic")
    end

    private

    def merge_controller(data, controller)
      data[:controller] = [data[:controller], controller].compact.join(" ")
      data
    end

    class MenuBuilder
      def initialize(context)
        @context = context
        @items = []
      end

      def item(title, url, method: nil, destructive: false, **options)
        data = options.delete(:data) || {}
        data[:bridge__menu_target] = "item"
        data[:turbo_method] = method if method
        data[:destructive] = "" if destructive

        @items << @context.link_to(title, url, **options, data: data, hidden: true)
      end

      def to_html
        @context.safe_join(@items)
      end
    end
  end
end
