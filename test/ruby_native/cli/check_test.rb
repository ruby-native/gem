require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "ruby_native/cli/check"

class CheckTest < Minitest::Test
  def test_a_clean_app_passes
    output = check(<<~ERB)
      <div data-native-tabs hidden></div>
      <%= link_to "Home", "/" %>
    ERB

    assert_match "Checked 1 template. No problems found.", output
  end

  def test_the_documented_paywall_passes
    output = check(<<~ERB)
      <div data-native-purchase="com.yourapp.pro.monthly"
           data-native-customer-id="<%= current_user.id %>"
           data-native-success-path="<%= dashboard_path %>">
        <span data-native-price="com.yourapp.pro.monthly">$9.99</span>
        <button type="submit">Subscribe</button>
      </div>
      <button data-native-restore>Restore purchases</button>
    ERB

    assert_match "No problems found.", output
  end

  def test_a_typo_is_an_error_with_a_suggestion
    output = check("<div data-native-tab hidden></div>", status: 1)

    assert_match "error", output
    assert_match "Unknown signal `data-native-tab`. Did you mean `data-native-tabs`?", output
  end

  def test_an_unrelated_attribute_is_reported_without_a_guess
    output = check("<div data-native-wombat hidden></div>", status: 1)

    assert_match "Unknown signal `data-native-wombat`.", output
    refute_match "Did you mean", output
  end

  def test_a_duplicate_singleton_is_a_warning_and_does_not_fail
    output = check(<<~ERB)
      <div data-native-tabs hidden></div>
      <div data-native-tabs hidden></div>
    ERB

    assert_match "2 elements carry `data-native-tabs`; only the first one is used.", output
    assert_match "0 errors, 1 warning", output
  end

  def test_a_repeated_non_singleton_is_fine
    output = check(<<~ERB)
      <button data-native-menu-item="a">A</button>
      <button data-native-menu-item="b">B</button>
    ERB

    assert_match "No problems found.", output
  end

  # Herb's compiler rejects ERB in attribute position, but its parser does not,
  # and whether their ERB is Rails 8.2 ready is not this command's business.
  def test_markup_herbs_compiler_would_reject_is_not_an_error
    assert_match "No problems found.", check(%(<option value="a" <%= "selected" if @x %>>A</option>))
  end

  def test_a_template_that_would_not_compile_still_gets_its_signals_checked
    output = check(%(<div data-native-tab <%= "hidden" if @x %>></div>), status: 1)

    assert_match "Unknown signal `data-native-tab`", output
    refute_match "attribute position", output
  end

  def test_a_signal_newer_than_the_gem_is_an_error
    with_version("0.14.0") do
      output = check("<div data-native-keyboard-toolbar hidden></div>", status: 1)

      assert_match "`data-native-keyboard-toolbar` needs Ruby Native 0.15.0, but this app is on 0.14.0.", output
    end
  end

  def test_a_signal_the_gem_already_has_passes
    with_version("0.15.0") do
      assert_match "No problems found.", check("<div data-native-keyboard-toolbar hidden></div>")
    end
  end

  def test_a_signal_whose_value_comes_from_erb_is_still_recognized
    assert_match "No problems found.", check(%(<div data-native-badge-tab="<%= @count %>" hidden></div>))
  end

  # An attribute name that only exists at render time cannot be resolved
  # statically, and guessing at one would be worse than skipping it.
  def test_an_attribute_name_built_from_erb_is_skipped
    assert_match "No problems found.", check(%(<div <%= @attribute %>="x"></div>))
  end

  def test_signals_outside_the_scanned_paths_are_not_checked
    output = check("<div data-native-tab hidden></div>", paths: "app/components")

    assert_match "No .html.erb templates found in app/components.", output
  end

  def test_an_app_with_no_templates_says_so
    in_app do
      assert_match "No .html.erb templates found", run_check([])
    end
  end

  def test_signal_offenses_returns_the_signal_problems_deploy_cares_about
    in_app do
      FileUtils.mkdir_p("app/views/pages")
      File.write("app/views/pages/show.html.erb", "<div data-native-tab hidden></div>")

      offenses = RubyNative::CLI::Check.signal_offenses

      assert_equal 1, offenses.size
      assert_match "Unknown signal `data-native-tab`", offenses.first.message
    end
  end

  # Deploy runs this, and a Rails 8.2 concern must not block a build today.
  def test_signal_offenses_does_not_flag_templates_that_would_not_compile
    in_app do
      FileUtils.mkdir_p("app/views/pages")
      File.write("app/views/pages/show.html.erb", %(<option value="a" <%= "selected" if @x %>>A</option>))

      assert_empty RubyNative::CLI::Check.signal_offenses
    end
  end

  def test_signal_offenses_is_nil_without_herb
    klass = RubyNative::CLI::Check
    original = klass.method(:herb_available?)
    klass.singleton_class.send(:remove_method, :herb_available?)
    klass.define_singleton_method(:herb_available?) { false }

    assert_nil klass.signal_offenses
  ensure
    klass.singleton_class.send(:remove_method, :herb_available?)
    klass.define_singleton_method(:herb_available?, original)
  end

  def test_a_signal_newer_than_the_deployed_build_is_an_error
    offenses = deployed_offenses_for("ios", built: "0.9.2", signal: "data-native-keyboard-toolbar")

    assert_equal 1, offenses.size
    assert_equal "`data-native-keyboard-toolbar` needs 0.15.0, but the ios build users have was made on 0.9.2.",
      offenses.first.message
  end

  def test_a_signal_the_deployed_build_already_understands_passes
    assert_empty deployed_offenses_for("ios", built: "0.15.3", signal: "data-native-keyboard-toolbar")
  end

  def test_a_shell_written_signal_is_never_compared_against_a_build
    assert_empty deployed_offenses_for("ios", built: "0.1.2", signal: "data-native-app")
  end

  def test_an_unreachable_api_reports_nothing_rather_than_failing
    check = RubyNative::CLI::Check.new(["--deployed"])
    check.define_singleton_method(:latest_build_version) { |*| nil }

    assert_empty check.send(:deployed_offenses_for, "ios", "app_1", { "data-native-tabs" => ["a.erb", 1] })
  end

  def test_a_helper_called_twice_is_a_warning
    output = check(<<~ERB)
      <%= native_fab_tag icon: "plus", href: "/new" %>
      <%= native_fab_tag icon: "plus", href: "/new" %>
    ERB

    assert_match "2 elements carry `data-native-fab`; only the first one is used.", output
    assert_match "0 errors, 1 warning", output
  end

  def test_a_helper_called_once_is_fine
    assert_match "No problems found.", check(%(<%= native_fab_tag icon: "plus" %>))
  end

  # native_tabs_tag(enabled: false) renders nothing, so a call is not proof the
  # signal reaches the page. Missing this duplicate is the deliberate cost of
  # never warning about markup that was never rendered. Written out as two
  # attributes it still warns.
  def test_a_helper_that_can_render_nothing_is_not_counted
    output = check(<<~ERB)
      <%= native_tabs_tag %>
      <%= native_tabs_tag %>
    ERB

    assert_match "No problems found.", output
  end

  # `<%= native_navbar_tag "Orders" do |navbar| %>` opens a block, so its Ruby
  # never reaches the parser as a complete expression on its own.
  def test_a_helper_in_block_form_counts
    output = check(<<~ERB)
      <%= native_navbar_tag "Orders" do |navbar| %>
        <%= navbar.button "Export", href: "/export" %>
      <% end %>
      <%= native_navbar_tag "Filters" %>
    ERB

    assert_match "2 elements carry `data-native-navbar`", output
  end

  def test_a_helper_nested_in_a_conditional_counts
    output = check(<<~ERB)
      <%= native_push_tag %>
      <% if @admin %>
        <%= native_push_tag %>
      <% end %>
    ERB

    assert_match "2 elements carry `data-native-push`", output
  end

  def test_a_helper_and_the_attribute_it_emits_count_together
    output = check(<<~ERB)
      <div data-native-push hidden></div>
      <%= native_push_tag %>
    ERB

    assert_match "2 elements carry `data-native-push`", output
  end

  # Parsing rather than scanning for helper names is the whole point: a literal
  # that happens to spell one is a string, not a call.
  def test_a_helper_name_inside_a_string_is_not_a_call
    output = check(<<~ERB)
      <%= native_push_tag %>
      <%= f.text_field :name, placeholder: "native_push_tag" %>
    ERB

    assert_match "No problems found.", output
  end

  def test_a_helper_name_inside_an_erb_comment_is_not_a_call
    output = check(<<~ERB)
      <%= native_push_tag %>
      <%# native_push_tag is documented at rubynative.com/docs %>
    ERB

    assert_match "No problems found.", output
  end

  # A helper emits some signals only when passed the matching argument, so a
  # bare call must not be counted against them.
  def test_a_conditional_signal_is_not_counted_from_a_helper_call
    with_version("0.13.0") do
      assert_match "No problems found.", check(%(<%= native_fab_tag icon: "plus" %>))
    end
  end

  # Ruby that does not parse is the app's own syntax error. Rails raises on
  # render and `herb lint` reports it properly; `check` stays quiet.
  def test_ruby_that_does_not_parse_is_skipped_rather_than_crashing
    output = check(<<~ERB)
      <%= native_navbar_tag "unterminated %>
      <%= native_push_tag %>
    ERB

    assert_match "No problems found.", output
  end

  def test_deploy_sees_helper_calls_too
    in_app do
      FileUtils.mkdir_p("app/views/pages")
      File.write("app/views/pages/show.html.erb", "<%= native_push_tag %>\n<%= native_push_tag %>")

      offenses = RubyNative::CLI::Check.signal_offenses

      assert_equal 1, offenses.size
      assert_match "2 elements carry `data-native-push`", offenses.first.message
    end
  end

  private

  def deployed_offenses_for(platform, built:, signal:)
    check = RubyNative::CLI::Check.new(["--deployed"])
    check.define_singleton_method(:latest_build_version) { |*| built }

    check.send(:deployed_offenses_for, platform, "app_1", { signal => ["app/views/pages/show.html.erb", 3] })
  end

  def check(template, status: 0, paths: nil)
    in_app do
      FileUtils.mkdir_p("app/views/pages")
      File.write("app/views/pages/show.html.erb", template)

      run_check(paths ? ["--paths=#{paths}"] : [], status: status)
    end
  end

  def run_check(argv, status: 0)
    output, exited = capture_exit { RubyNative::CLI::Check.new(argv).run }

    assert_equal status, exited, "expected exit #{status}\n#{output}"
    output
  end

  def in_app(&block)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir, &block)
    end
  end

  # `run` exits on failure, so the status is part of what each case asserts.
  def capture_exit
    exited = 0

    output, = capture_io do
      yield
    rescue SystemExit => error
      exited = error.status
    end

    [output, exited]
  end

  def with_version(version)
    original = RubyNative::VERSION
    RubyNative.send(:remove_const, :VERSION)
    RubyNative.const_set(:VERSION, version)
    yield
  ensure
    RubyNative.send(:remove_const, :VERSION)
    RubyNative.const_set(:VERSION, original)
  end
end
