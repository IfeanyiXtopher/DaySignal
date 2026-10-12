require "test_helper"

class WeatherMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
    @forecast = Forecast.new(
      precipitation_probability: 72,
      summary: "light rain",
      wind_speed: 3.5,
      raw: {}
    )
    @decision = AlertEvaluator::Decision.new(
      trigger: true,
      reason: "precipitation_probability=72 >= threshold=50",
      recommendation: "Rain likely for Lagos, Nigeria: 72% chance of precipitation (threshold 50%)."
    )
  end

  test "alert_email renders location and reason" do
    email = WeatherMailer.alert_email(@user, @forecast, @decision)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email_address ], email.to
    assert_match(/Weather alert for Lagos, Nigeria/, email.subject)

    text = email.text_part.decoded
    assert_match(/Lagos, Nigeria/, text)
    assert_match(/72%/, text)
    assert_match(/precipitation_probability=72/, text)
    assert_match(/threshold=50/, text)
    assert_match(/Rain likely for Lagos/, text)
  end
end

