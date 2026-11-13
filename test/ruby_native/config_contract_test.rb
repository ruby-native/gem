require "test_helper"
require "ruby_native/cli/mcp/config_validator"

# The gem's half of the config contract. The native repo decodes a copy of the
# same golden file on iOS and Android, so a change here has to land there too.
class RubyNative::ConfigContractTest < ActionDispatch::IntegrationTest
  FIXTURES = File.expand_path("../fixtures/contract", __dir__)
  YAML_FIXTURE = File.join(FIXTURES, "ruby_native.yml")
  LOCALES_FIXTURE = File.join(FIXTURES, "locales.yml")
  GOLDEN = File.join(FIXTURES, "config.json")
  Validator = RubyNative::CLI::Mcp::ConfigValidator

  MISMATCH = <<~MESSAGE
    /native/config.json no longer matches test/fixtures/contract/config.json.

    If the change is intended, regenerate the golden file:

      UPDATE_CONTRACT=1 bundle exec rake test TEST=test/ruby_native/config_contract_test.rb

    Then copy it to shared/fixtures/config.json in the native repo, so the iOS
    and Android decoders are tested against the JSON this gem now serves.
  MESSAGE

  def setup
    @config_path = Rails.root.join("config", "ruby_native.yml")
    @original_config = @config_path.read
    @config_path.write(File.read(YAML_FIXTURE))

    YAML.load_file(LOCALES_FIXTURE).each do |locale, translations|
      I18n.backend.store_translations(locale, translations)
    end
    I18n.available_locales = [:en, :it]
  end

  def teardown
    @config_path.write(@original_config)
    RubyNative.load_config
    I18n.backend.reload!
    I18n.available_locales = nil
  end

  def test_the_served_config_matches_the_golden_file
    get "/native/config.json"
    assert_response :ok
    served = JSON.pretty_generate(sort_keys(JSON.parse(response.body))) + "\n"

    if ENV["UPDATE_CONTRACT"] == "1"
      File.write(GOLDEN, served, encoding: "UTF-8")
    else
      golden = File.exist?(GOLDEN) ? File.read(GOLDEN, encoding: "UTF-8") : ""
      assert_equal golden, served, MISMATCH
    end
  end

  def test_the_version_rides_a_header_and_stays_out_of_the_body
    get "/native/config.json"

    assert_equal RubyNative::VERSION, response.headers["X-Ruby-Native-Version"]
    refute_includes response.body, RubyNative::VERSION
  end

  def test_the_fixture_is_a_config_the_validator_accepts
    assert_empty Validator.run(path: YAML_FIXTURE).map(&:message)
  end

  # A key added to the validator has to be added to the fixture too, or the
  # golden file stops covering what the gem serves.
  def test_the_golden_file_covers_every_key_the_validator_knows
    config = JSON.parse(File.read(GOLDEN, encoding: "UTF-8"))
    appearance = config.fetch("appearance")
    tab_keys = config.fetch("tabs").flat_map(&:keys).uniq

    assert_empty Validator::TOP_LEVEL_KEYS - config.keys
    assert_empty Validator::APP_KEYS - config.fetch("app").keys
    assert_empty Validator::APPEARANCE_KEYS - appearance.keys
    assert_empty Validator::NAVBAR_KEYS - appearance.fetch("navbar").keys
    assert_empty Validator::SPLASH_KEYS - appearance.fetch("splash").keys
    assert_empty Validator::TAB_KEYS - tab_keys
    assert_empty Validator::ANDROID_KEYS - config.fetch("android").keys
    assert_empty Validator::FIREBASE_KEYS - config.dig("android", "firebase").keys
  end

  private

  def sort_keys(value)
    case value
    when Hash then value.sort.to_h { |key, nested| [key, sort_keys(nested)] }
    when Array then value.map { |nested| sort_keys(nested) }
    else value
    end
  end
end
