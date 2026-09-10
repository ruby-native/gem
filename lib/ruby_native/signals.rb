require "yaml"

module RubyNative
  # The signal vocabulary, loaded from config/signals.yml. This is the single
  # source of truth for what a valid data-native-* attribute is: `ruby_native
  # check` validates views against it, and the native shells assert their own
  # copy matches.
  module Signals
    PATH = File.expand_path("../../config/signals.yml", __dir__)

    class << self
      def all
        @all ||= YAML.load_file(PATH).fetch("signals").freeze
      end

      def names
        @names ||= all.keys.freeze
      end

      def known?(name)
        all.key?(name)
      end

      # Signals read via querySelector, where only the first match wins, so a
      # second one on the same page is silently ignored.
      def singletons
        @singletons ||= all.select { |_name, meta| meta["singleton"] }.keys.freeze
      end

      def singleton?(name)
        singletons.include?(name)
      end

      # The gem version that introduced the signal. nil for signals the app
      # writes into the page rather than ones your views emit.
      def since(name)
        all.dig(name, "since")
      end

      def helper(name)
        all.dig(name, "helper")
      end

      # Signals a helper emits on every call, keyed by helper name. Only
      # `always` signals are listed: native_fab_tag can emit data-native-color,
      # but only when you pass `color:`, so counting it against a call would
      # have `check` report markup the view never renders.
      def helper_signals
        @helper_signals ||= begin
          map = {}
          all.each do |name, meta|
            helper = meta["helper"]
            (map[helper] ||= []) << name if helper && meta["always"]
          end
          map.freeze
        end
      end

      def signals_for_helper(helper)
        helper_signals.fetch(helper, [])
      end

      # Closest known signal within one or two edits, for "did you mean". A
      # genuinely unrelated attribute gets no suggestion rather than a
      # confusing one.
      def nearest(name, threshold: 2)
        # Ties on edit distance break toward the longer shared prefix, so a
        # typo'd `data-native-tab` suggests `data-native-tabs` rather than
        # `data-native-fab`, which is just as close by raw distance.
        candidate = names.min_by { |known| [distance(name, known), -common_prefix_length(name, known)] }
        candidate if candidate && distance(name, candidate) <= threshold
      end

      private

      def common_prefix_length(a, b)
        length = 0
        length += 1 while length < a.length && length < b.length && a[length] == b[length]
        length
      end

      def distance(a, b)
        rows = Array.new(a.length + 1) { |i| [i] + Array.new(b.length, 0) }
        (0..b.length).each { |j| rows[0][j] = j }

        (1..a.length).each do |i|
          (1..b.length).each do |j|
            cost = a[i - 1] == b[j - 1] ? 0 : 1
            rows[i][j] = [rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost].min
          end
        end

        rows[a.length][b.length]
      end
    end
  end
end
