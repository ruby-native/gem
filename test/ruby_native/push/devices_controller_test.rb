require "test_helper"

class RubyNative::Push::DevicesControllerTest < ActionDispatch::IntegrationTest
  def setup
    ApplicationPushDevice.delete_all
    User.delete_all
    @user = User.create!(name: "Ada")
    @original_resolver = RubyNative.current_user_resolver
  end

  def teardown
    RubyNative.current_user_resolver = @original_resolver
    ApplicationController.require_sign_in = false
  end

  # --- What the shells send ---

  def test_registers_the_token_ios_sends
    register(@user, token: "apns-token", platform: "apple", name: "Ada's iPhone")

    assert_response :ok
    assert_empty response.body
    device = @user.push_devices.sole
    assert_equal "apns-token", device.token
    assert_equal "apple", device.platform
    assert_equal "Ada's iPhone", device.name
  end

  def test_registers_the_token_android_sends
    register(@user, token: "fcm-token", platform: "google", name: "Google Pixel 9")

    assert_response :ok
    device = @user.push_devices.sole
    assert_equal "fcm-token", device.token
    assert_equal "google", device.platform
    assert_equal "Google Pixel 9", device.name
  end

  def test_the_endpoint_only_answers_post
    get "/native/push/devices"

    assert_response :not_found
  end

  # Neither shell sends a CSRF token, so the endpoint has to opt out of the
  # check it inherits from the host app.
  def test_skips_the_forgery_check_the_host_app_enforces
    assert ApplicationController.allow_forgery_protection
    assert_includes callbacks_for(ApplicationController), :verify_authenticity_token

    register(@user, token: "apns-token", platform: "apple", name: "iPhone")

    assert_response :ok
    refute_includes callbacks_for(RubyNative::Push::DevicesController), :verify_authenticity_token
  end

  # --- Repeat registrations ---

  def test_registering_the_same_token_again_keeps_one_device
    register(@user, token: "apns-token", platform: "apple", name: "Ada's iPhone")
    register(@user, token: "apns-token", platform: "apple", name: "Ada's iPhone")

    assert_response :ok
    assert_equal 1, ApplicationPushDevice.count
  end

  def test_registering_the_same_token_again_updates_the_name
    register(@user, token: "apns-token", platform: "apple", name: "iPhone")
    register(@user, token: "apns-token", platform: "apple", name: "Ada's iPhone")

    assert_equal "Ada's iPhone", @user.push_devices.sole.name
  end

  def test_a_second_token_adds_a_second_device
    register(@user, token: "apns-token", platform: "apple", name: "Ada's iPhone")
    register(@user, token: "fcm-token", platform: "google", name: "Google Pixel 9")

    assert_equal %w[apns-token fcm-token], @user.push_devices.order(:token).pluck(:token)
  end

  # The lookup is scoped to the signed-in user, so a phone that changes
  # accounts stays registered to the first one too.
  def test_the_same_token_under_a_second_user_gets_its_own_device
    other = User.create!(name: "Grace")

    register(@user, token: "apns-token", platform: "apple", name: "Shared iPhone")
    register(other, token: "apns-token", platform: "apple", name: "Shared iPhone")

    assert_response :ok
    assert_equal 1, @user.push_devices.count
    assert_equal 1, other.push_devices.count
  end

  # --- Who the device belongs to ---

  def test_a_host_filter_that_halts_runs_before_the_registration
    ApplicationController.require_sign_in = true

    register(nil, token: "apns-token", platform: "apple", name: "iPhone")

    assert_response :unauthorized
    assert_equal 0, ApplicationPushDevice.count
  end

  # Both shells resend the token until they get a 2xx.
  def test_a_request_with_no_user_is_not_a_success
    register(nil, token: "apns-token", platform: "apple", name: "iPhone")

    refute_predicate response, :successful?
    assert_equal 0, ApplicationPushDevice.count
  end

  def test_the_resolver_can_name_another_controller_method
    ApplicationController.class_eval do
      private def current_person = User.find_by(name: "Ada")
    end
    RubyNative.current_user_resolver = :current_person

    register(nil, token: "apns-token", platform: "apple", name: "iPhone")

    assert_response :ok
    assert_equal 1, @user.push_devices.count
  ensure
    ApplicationController.send(:remove_method, :current_person)
  end

  def test_a_callable_resolver_runs_inside_the_controller
    RubyNative.current_user_resolver = -> { User.find_by(id: cookies[:pairing_id]) }

    post "/native/push/devices",
      params: {token: "apns-token", platform: "apple", name: "iPhone"}.to_json,
      headers: {"CONTENT_TYPE" => "application/json", "Cookie" => "pairing_id=#{@user.id}"}

    assert_response :ok
    assert_equal 1, @user.push_devices.count
  end

  # --- Bad input ---

  def test_an_unknown_platform_returns_unprocessable_entity
    register(@user, token: "apns-token", platform: "ios", name: "iPhone")

    assert_response :unprocessable_entity
    assert_equal 0, ApplicationPushDevice.count
  end

  def test_a_missing_token_returns_bad_request
    register(@user, platform: "apple", name: "iPhone")

    assert_response :bad_request
    assert_equal 0, ApplicationPushDevice.count
  end

  def test_a_nonscalar_token_returns_bad_request
    register(@user, token: {value: "apns-token"}, platform: "apple", name: "iPhone")

    assert_response :bad_request
    assert_equal 0, ApplicationPushDevice.count
  end

  def test_the_name_is_optional
    register(@user, token: "apns-token", platform: "apple")

    assert_response :ok
    assert_nil @user.push_devices.sole.name
  end

  private

  # JSON body, session cookie, no CSRF token: the request both shells make.
  def register(user, **body)
    headers = {"CONTENT_TYPE" => "application/json"}
    headers["Cookie"] = "user_id=#{user.id}" if user

    post "/native/push/devices", params: body.to_json, headers: headers
  end

  def callbacks_for(controller)
    controller._process_action_callbacks.map(&:filter)
  end
end
