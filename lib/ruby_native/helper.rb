module RubyNative
  module Helper
    def native_app?
      request.user_agent.to_s.include?("Ruby Native")
    end

    def native_tabs_tag
      tag.div(data: { native_tabs: true }, hidden: true)
    end

    def native_form_tag
      tag.div(data: { native_form: true }, hidden: true)
    end

    def native_push_tag
      tag.div(data: { native_push: true }, hidden: true)
    end
  end
end
