require "test_helper"

class PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "edit requires authentication" do
    sign_out
    get edit_preferences_path
    assert_redirected_to new_session_path
  end

  test "update saves valid preferences" do
    patch preferences_path, params: {
      user: {
        location_label: "Ibadan, Nigeria",
        latitude: 7.3775,
        longitude: 3.9470,
        timezone: "Africa/Lagos",
        alert_time: "09:00",
        rain_threshold: 60,
        alerts_enabled: "1"
      }
    }

    assert_redirected_to root_path
    @user.reload
    assert_equal "Ibadan, Nigeria", @user.location_label
    assert_equal 60, @user.rain_threshold
  end

  test "update rejects invalid threshold" do
    patch preferences_path, params: {
      user: {
        location_label: @user.location_label,
        latitude: @user.latitude,
        longitude: @user.longitude,
        timezone: @user.timezone,
        alert_time: "07:00",
        rain_threshold: 200,
        alerts_enabled: "1"
      }
    }

    assert_response :unprocessable_entity
    @user.reload
    assert_equal 50, @user.rain_threshold
  end

  test "update rejects invalid timezone" do
    patch preferences_path, params: {
      user: {
        location_label: @user.location_label,
        latitude: @user.latitude,
        longitude: @user.longitude,
        timezone: "Mars/Phobos",
        alert_time: "07:00",
        rain_threshold: 50,
        alerts_enabled: "1"
      }
    }

    assert_response :unprocessable_entity
  end
end
