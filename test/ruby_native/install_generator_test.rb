require "test_helper"
require "rails/generators/test_case"
require "generators/ruby_native/install_generator"
require "yaml"

class RubyNative::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests RubyNative::Generators::InstallGenerator
  destination File.expand_path("../../tmp/install_generator", __dir__)
  setup :prepare_destination

  HOST_LINE = %(config.hosts << ".trycloudflare.com" if config.hosts.is_a?(Array))

  def test_adds_guarded_host_line_to_standard_configure_block
    write_dev_config <<~RUBY
      Rails.application.configure do
        config.enable_reloading = true
      end
    RUBY

    run_generator

    assert_dev_config_includes "Rails.application.configure do\n  #{HOST_LINE}\n"
  end

  def test_adds_host_line_to_custom_configure_block
    write_dev_config <<~RUBY
      Backerkit::Application.configure do
        config.enable_reloading = true
      end
    RUBY

    run_generator

    assert_dev_config_includes "Backerkit::Application.configure do\n  #{HOST_LINE}\n"
  end

  def test_leaves_file_alone_when_no_configure_block_exists
    write_dev_config "# frozen_string_literal: true\n"

    output = run_generator

    refute_includes dev_config_contents, "trycloudflare"
    assert_includes output, "Add this line inside it"
  end

  def test_does_not_duplicate_an_existing_host_line
    write_dev_config <<~RUBY
      Rails.application.configure do
        config.hosts << ".trycloudflare.com"
      end
    RUBY

    run_generator

    assert_equal 1, dev_config_contents.scan("trycloudflare").count
  end

  def test_runs_without_a_development_environment_file
    run_generator

    assert_file "config/ruby_native.yml"
  end

  # --- Tabs from routes ---

  def test_writes_tabs_for_the_routes_the_app_actually_has
    with_routes do
      root "pages#home"
      get "/profile", to: "pages#profile"
      get "/sign_in", to: "sessions#new"
      get "/settings", to: "pages#settings"
      resources :posts
    end

    output = run_generator

    assert_file "config/ruby_native.yml" do |config|
      tabs = YAML.safe_load(config)["tabs"]
      assert_equal [ "/", "/profile", "/settings", "/posts" ], tabs.map { |tab| tab["path"] }
      assert_equal [ "Home", "Profile", "Settings", "Posts" ], tabs.map { |tab| tab["title"] }
      assert_equal [ "house", "person", "gear", "list.bullet" ], tabs.map { |tab| tab["icon"] }
    end
    assert_includes output, "Tabs, from your routes: / (Home), /profile (Profile), /settings (Settings), /posts (Posts)"
    assert_includes output, "bundle exec ruby_native mcp install"
    assert_includes output, "Then, in your agent: /mcp__ruby-native__ship"
    assert output.index("bundle exec ruby_native preview") < output.index("mcp install"), "the agent hand-off is the last thing printed"
  end

  def test_skips_the_routes_a_library_draws_into_the_app
    with_routes do
      get "/recede_historical_location", to: "turbo/native/navigation#recede"
      get "/resume_historical_location", to: "turbo/native/navigation#resume"
      get "/manifest", to: "rails/pwa#manifest"
      get "/inbox", to: "pages#inbox"
    end

    run_generator

    assert_file "config/ruby_native.yml" do |config|
      assert_equal [ "/inbox" ], YAML.safe_load(config)["tabs"].map { |tab| tab["path"] }
    end
  end

  def test_puts_root_first_and_skips_parameterized_and_nested_paths
    with_routes do
      get "/orders", to: "orders#index"
      get "/orders/:id", to: "orders#show"
      get "/account/billing", to: "billing#show"
      get "/files/*path", to: "files#show"
      root "pages#home"
    end

    run_generator

    assert_file "config/ruby_native.yml" do |config|
      assert_equal [ "/", "/orders" ], YAML.safe_load(config)["tabs"].map { |tab| tab["path"] }
    end
  end

  def test_caps_the_tabs_and_gives_unknown_pages_a_neutral_icon
    with_routes do
      root "pages#home"
      %w[alpha beta gamma delta epsilon].each { |name| get "/#{name}", to: "pages##{name}" }
    end

    run_generator

    assert_file "config/ruby_native.yml" do |config|
      tabs = YAML.safe_load(config)["tabs"]
      assert_equal 4, tabs.size
      assert_equal "list.bullet", tabs.last["icon"]
      assert_equal "Gamma", tabs.last["title"]
    end
  end

  # A tab that 404s is worse than no tab, and the shell hides the bar below
  # two tabs, so the generator says so rather than inventing a page.
  def test_writes_only_the_root_when_nothing_else_is_routable_and_says_the_bar_is_hidden
    with_routes { root "pages#home" }

    output = run_generator

    assert_file "config/ruby_native.yml" do |config|
      assert_equal [ "/" ], YAML.safe_load(config)["tabs"].map { |tab| tab["path"] }
    end
    assert_includes output, "The tab bar stays hidden until config/ruby_native.yml has a second tab."
  end

  def test_falls_back_to_the_root_when_routes_cannot_be_read
    with_routes {}

    run_generator

    assert_file "config/ruby_native.yml" do |config|
      assert_equal [ "/" ], YAML.safe_load(config)["tabs"].map { |tab| tab["path"] }
    end
  end

  private

  def with_routes(&block)
    Rails.application.routes.draw(&block)
  end

  def teardown
    Rails.application.routes.draw {}
  end

  def write_dev_config(contents)
    dir = File.join(destination_root, "config/environments")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "development.rb"), contents)
  end

  def dev_config_contents
    File.read(File.join(destination_root, "config/environments/development.rb"))
  end

  def assert_dev_config_includes(snippet)
    assert_includes dev_config_contents, snippet
  end
end
