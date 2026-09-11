require "prism"

module RubyNative
  class CLI
    class Check
      # Walks a parsed template and records every data-native-* signal with the
      # lines it appears on, whether the view writes the attribute by hand or
      # calls the helper that emits it. Attribute names built out of ERB cannot
      # be resolved statically and are skipped rather than guessed at.
      #
      # Subclasses Herb::Visitor, so this file is only loaded once `herb` is
      # known to be present.
      class SignalCollector < Herb::Visitor
        COMMENT_OPENING = "<%#".freeze

        def initialize
          @signals = {}
          super
        end

        # Attributes and helper calls arrive from different visits, so the lines
        # for one signal are not collected in document order.
        def signals
          @signals.transform_values(&:sort)
        end

        def visit_html_attribute_name_node(node)
          name = node.children.filter_map { |child| child.content if child.respond_to?(:content) }.join

          record(name, node.location.start.line) if name.start_with?("data-native-")

          super
        end

        def visit_erb_content_node(node)
          record_helper_calls(node)

          super
        end

        # `<%= native_navbar_tag "Orders" do |navbar| %>` opens a block, so its
        # Ruby arrives here instead, without the `end` that would let it parse
        # on its own.
        def visit_erb_block_node(node)
          record_helper_calls(node, suffix: "\nend")

          super
        end

        private

        def record_helper_calls(node, suffix: "")
          return if node.tag_opening&.value == COMMENT_OPENING

          source = node.content&.value
          return if source.nil?

          # Ruby that does not parse is the app's own syntax error, which Rails
          # raises on render and `herb lint` reports properly. Staying quiet
          # here keeps `check` to the one job it claims.
          result = Prism.parse(source + suffix)
          return unless result.success?

          line = node.location.start.line
          calls(result.value).each do |call|
            helper = call.name.to_s
            signals = RubyNative::Signals.signals_for_helper(helper)
            next if signals.empty? || !renders?(call, helper)

            signals.each { |signal| record(signal, line) }
          end
        end

        # A helper that can render nothing only counts when its arguments prove
        # it renders. `native_tabs_tag(enabled: @show)` decides at request time,
        # so it is skipped rather than guessed at, the same as an attribute name
        # built out of ERB.
        def renders?(call, helper)
          condition = RubyNative::Signals.render_condition(helper)
          return true unless condition

          condition.all? do |keyword, required|
            given = keyword_value(call, keyword)

            given.nil? ? true : given == required
          end
        end

        # nil when the keyword is absent, which leaves the helper's own default
        # in charge. :unknown for anything that is not a literal, so it never
        # equals what the condition requires.
        def keyword_value(call, keyword)
          pairs = call.arguments&.arguments&.grep(Prism::KeywordHashNode)&.flat_map(&:elements)
          return nil if pairs.nil?

          assoc = pairs.find do |pair|
            pair.is_a?(Prism::AssocNode) && pair.key.is_a?(Prism::SymbolNode) &&
              pair.key.unescaped == keyword.to_s
          end
          return nil unless assoc

          case assoc.value
          when Prism::TrueNode then true
          when Prism::FalseNode then false
          else :unknown
          end
        end

        # A literal in an argument is not a call, so `placeholder: "native_tabs_tag"`
        # reads as the string it is. That is the whole reason for parsing rather
        # than scanning the source for helper names.
        def calls(root)
          found = []
          stack = [root]

          while (node = stack.pop)
            next unless node.is_a?(Prism::Node)

            found << node if node.is_a?(Prism::CallNode)
            stack.concat(node.compact_child_nodes)
          end

          found
        end

        def record(name, line)
          (@signals[name] ||= []) << line
        end
      end
    end
  end
end
