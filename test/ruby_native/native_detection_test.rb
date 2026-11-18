require "test_helper"

class RubyNative::NativeDetectionTest < Minitest::Test
  FakeRequest = Struct.new(:user_agent, :cookies) do
    def initialize(user_agent, cookies = {}) = super
  end

  class FakeController
    include RubyNative::NativeDetection

    attr_accessor :request

    def initialize(request)
      @request = request
    end
  end

  def test_native_app_returns_true_for_ruby_native_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.2.0"))
    assert controller.native_app?
  end

  def test_native_app_returns_false_for_browser_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    refute controller.native_app?
  end

  def test_native_app_returns_false_for_nil_user_agent
    controller = FakeController.new(FakeRequest.new(nil))
    refute controller.native_app?
  end

  def test_native_app_returns_true_when_user_agent_contains_ruby_native
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0 Ruby Native iOS/1.4 RubyNative/0.2.0 CFNetwork"))
    assert controller.native_app?
  end

  def test_native_version_returns_package_version_from_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.2.0"))
    assert_equal RubyNative::NativeVersion.new("0.2.0"), controller.native_version
  end

  def test_native_version_returns_package_version_not_app_version
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/2.5 RubyNative/0.2.0"))
    assert_equal RubyNative::NativeVersion.new("0.2.0"), controller.native_version
  end

  def test_native_version_returns_package_version_embedded_in_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0 Ruby Native iOS/1.4 RubyNative/0.3.1 CFNetwork"))
    assert_equal RubyNative::NativeVersion.new("0.3.1"), controller.native_version
  end

  def test_native_version_returns_zero_for_browser_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    assert_equal RubyNative::NativeVersion.new("0"), controller.native_version
  end

  def test_native_version_returns_zero_for_nil_user_agent
    controller = FakeController.new(FakeRequest.new(nil))
    assert_equal RubyNative::NativeVersion.new("0"), controller.native_version
  end

  def test_native_version_returns_zero_for_old_user_agent_without_package_version
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4"))
    assert_equal RubyNative::NativeVersion.new("0"), controller.native_version
  end

  def test_native_version_handles_three_part_version
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.0 RubyNative/1.3.2"))
    assert_equal RubyNative::NativeVersion.new("1.3.2"), controller.native_version
  end

  def test_native_version_supports_string_comparison
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.2.0"))
    assert controller.native_version >= "0.1.0"
    refute controller.native_version >= "1.0.0"
  end

  def test_native_platform_returns_ios_for_ios_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.8.0"))
    assert_equal "ios", controller.native_platform
  end

  def test_native_platform_returns_android_for_android_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native Android/0.1.0 RubyNative/0.8.0"))
    assert_equal "android", controller.native_platform
  end

  def test_native_platform_returns_nil_for_web_browser
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    assert_nil controller.native_platform
  end

  def test_native_platform_returns_nil_for_nil_user_agent
    controller = FakeController.new(FakeRequest.new(nil))
    assert_nil controller.native_platform
  end

  FULL_IOS_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
    "Ruby Native iOS/5.2/35 iOS/26.5.2 RubyNative/0.12.6 Hotwire Native iOS; Turbo Native iOS; bridge-components: []"
  FULL_ANDROID_UA = "Ruby Native Android/5.3/44 Android/17 RubyNative/0.12.6 " \
    "Hotwire Native Android; Turbo Native Android; bridge-components: []; Mozilla/5.0 (Linux; Android 10; K; wv) AppleWebKit/537.36"

  def test_native_app_version_parses_full_ios_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_IOS_UA))
    assert_equal "5.2", controller.native_app_version
  end

  def test_native_app_build_parses_full_ios_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_IOS_UA))
    assert_equal "35", controller.native_app_build
  end

  def test_native_os_version_parses_full_ios_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_IOS_UA))
    assert_equal "26.5.2", controller.native_os_version
  end

  def test_native_version_parses_full_ios_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_IOS_UA))
    assert_equal RubyNative::NativeVersion.new("0.12.6"), controller.native_version
  end

  def test_native_app_version_parses_full_android_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_ANDROID_UA))
    assert_equal "5.3", controller.native_app_version
  end

  def test_native_app_build_parses_full_android_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_ANDROID_UA))
    assert_equal "44", controller.native_app_build
  end

  def test_native_os_version_parses_full_android_user_agent
    controller = FakeController.new(FakeRequest.new(FULL_ANDROID_UA))
    assert_equal "17", controller.native_os_version
  end

  OS_BUILD_IOS_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) " \
    "Ruby Native iOS/5.2/35 iOS/26.5.2/23F79 RubyNative/0.14.2 Hotwire Native iOS; Turbo Native iOS; bridge-components: []"
  OS_BUILD_ANDROID_UA = "Ruby Native Android/5.3/44 Android/17/UQ1A.240205.004 RubyNative/0.14.2 " \
    "Hotwire Native Android; Turbo Native Android; bridge-components: []; Mozilla/5.0 (Linux; Android 10; K; wv) AppleWebKit/537.36"

  def test_native_os_build_parses_ios_user_agent
    controller = FakeController.new(FakeRequest.new(OS_BUILD_IOS_UA))
    assert_equal "23F79", controller.native_os_build
  end

  def test_native_os_build_parses_android_user_agent
    controller = FakeController.new(FakeRequest.new(OS_BUILD_ANDROID_UA))
    assert_equal "UQ1A.240205.004", controller.native_os_build
  end

  def test_os_build_segment_does_not_break_the_other_helpers
    controller = FakeController.new(FakeRequest.new(OS_BUILD_IOS_UA))
    assert_equal "5.2", controller.native_app_version
    assert_equal "35", controller.native_app_build
    assert_equal "26.5.2", controller.native_os_version
    assert_equal RubyNative::NativeVersion.new("0.14.2"), controller.native_version
  end

  def test_native_os_build_returns_nil_for_user_agent_without_it
    controller = FakeController.new(FakeRequest.new(FULL_IOS_UA))
    assert_nil controller.native_os_build
  end

  def test_native_app_version_parses_old_format_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.2.0"))
    assert_equal "1.4", controller.native_app_version
  end

  def test_native_app_build_returns_nil_for_old_format_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.2.0"))
    assert_nil controller.native_app_build
  end

  def test_native_os_version_does_not_mistake_app_version_in_old_format_user_agent
    controller = FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.2.0"))
    assert_nil controller.native_os_version
  end

  def test_new_helpers_return_nil_for_browser_user_agent
    controller = FakeController.new(FakeRequest.new("Mozilla/5.0"))
    assert_nil controller.native_app_version
    assert_nil controller.native_app_build
    assert_nil controller.native_os_version
    assert_nil controller.native_os_build
  end

  def test_new_helpers_return_nil_for_nil_user_agent
    controller = FakeController.new(FakeRequest.new(nil))
    assert_nil controller.native_app_version
    assert_nil controller.native_app_build
    assert_nil controller.native_os_version
    assert_nil controller.native_os_build
  end

  def test_secure_session_completion_url_uses_the_app_scheme_cookie
    controller = secure_session_controller("rubynative-com-example-app")
    assert_equal "rubynative-com-example-app://secure-session?return_to=%2Fbank%2Fdone%3Fok%3D1",
      controller.native_secure_session_completion_url(return_to: "/bank/done?ok=1")
  end

  def test_secure_session_completion_url_is_nil_without_the_cookie
    assert_nil secure_session_controller(nil).native_secure_session_completion_url(return_to: "/bank/done")
  end

  def test_secure_session_completion_url_ignores_a_scheme_that_is_not_the_apps
    assert_nil secure_session_controller("javascript").native_secure_session_completion_url(return_to: "/bank/done")
    assert_nil secure_session_controller("https").native_secure_session_completion_url(return_to: "/bank/done")
  end

  def test_secure_session_completion_url_requires_a_path_on_the_site
    controller = secure_session_controller("rubynative-com-example-app")
    [ "https://evil.com", "//evil.com", "bank/done", "" ].each do |return_to|
      assert_raises(ArgumentError) { controller.native_secure_session_completion_url(return_to: return_to) }
    end
  end

  private

  def secure_session_controller(scheme)
    cookies = scheme ? { "_ruby_native_callback_scheme" => scheme } : {}
    FakeController.new(FakeRequest.new("Ruby Native iOS/1.4 RubyNative/0.19.2", cookies))
  end
end
