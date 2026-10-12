require "test_helper"

class WeatherAlertJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do

    @user = users(:one)
    @trigger_forecast = Forecast.new(
      precipitation_probability: 80,
      summary: "rain",
      wind_speed: 4.0,
      raw: { "max_rain_3h_mm" => 1.0 }
    )
    @quiet_forecast = Forecast.new(
      precipitation_probability: 10,
      summary: "clear sky",
      wind_speed: 1.0,
      raw: { "max_rain_3h_mm" => nil }
    )
  end

  test "trigger path delivers mail and sets last_alerted_at" do
    client = stub_client(@trigger_forecast)

    assert_emails 1 do
      WeatherAlertJob.perform_now(@user.id, client: client)
    end

    assert @user.reload.last_alerted_at.present?
  end

  test "non-trigger path sends nothing" do
    client = stub_client(@quiet_forecast)

    assert_no_emails do
      WeatherAlertJob.perform_now(@user.id, client: client)
    end

    assert_nil @user.reload.last_alerted_at
  end

  test "disabled alerts skip work" do
    @user.update!(alerts_enabled: false)
    client = stub_client(@trigger_forecast)

    assert_no_emails do
      WeatherAlertJob.perform_now(@user.id, client: client)
    end
  end

  test "missing user is a no-op" do
    assert_no_emails do
      WeatherAlertJob.perform_now(-1, client: stub_client(@trigger_forecast))
    end
  end

  private

  def stub_client(forecast)
    Class.new do
      define_method(:fetch) { |*_args| forecast }
    end.new
  end
end
