require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "rejects invalid timezone on preferences update" do
    user = users(:one)
    user.timezone = "Not/A_Zone"

    assert_not user.valid?(:preferences_update)
    assert_includes user.errors[:timezone], "is not a known timezone"
  end

  test "rejects rain_threshold outside 0..100" do
    user = users(:one)
    user.rain_threshold = 150

    assert_not user.valid?(:preferences_update)
    assert_predicate user.errors[:rain_threshold], :any?
  end

  test "rejects blank location on preferences update" do
    user = users(:one)
    user.location_label = ""

    assert_not user.valid?(:preferences_update)
    assert_predicate user.errors[:location_label], :any?
  end

  test "happy-path preferences persist" do
    user = users(:two)
    user.assign_attributes(
      location_label: "Accra, Ghana",
      latitude: 5.6037,
      longitude: -0.1870,
      timezone: "Africa/Accra",
      alert_time: "06:30",
      rain_threshold: 55,
      alerts_enabled: false
    )

    assert user.save(context: :preferences_update)
    user.reload
    assert_equal "Accra, Ghana", user.location_label
    assert_equal 55, user.rain_threshold
    assert_not user.alerts_enabled?
    assert_equal "Africa/Accra", user.timezone
  end

  test "alert_status_summary when enabled with complete prefs" do
    user = users(:one)
    assert_match(/Alerts on/, user.alert_status_summary)
    assert_match(/07:00/, user.alert_status_summary)
  end
end
