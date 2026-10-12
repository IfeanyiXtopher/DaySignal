require "test_helper"

# Encodes APPROACH §13 / BUILD_PLAN Step 5 Manual QA as automated checks.
# Network is always stubbed — CI never calls OpenWeatherMap or SMTP.
class ManualQaTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @user = users(:one) # Africa/Lagos, alert 07:00, threshold 50
  end

  test "QA1: Lagos due hour + threshold 0 + high POP → mail" do
    @user.update!(rain_threshold: 0, last_alerted_at: nil, alerts_enabled: true)
    client = stub_client(pop: 80)

    # 06:00 UTC == 07:00 Africa/Lagos
    travel_to Time.utc(2026, 10, 12, 6, 0, 0) do
      assert_enqueued_with(job: WeatherAlertJob, args: [ @user.id ]) do
        DispatchDueAlertsJob.perform_now
      end
    end

    assert_emails 1 do
      WeatherAlertJob.perform_now(@user.id, client: client)
    end
    assert @user.reload.last_alerted_at.present?
  end

  test "QA2: threshold 100 + low POP → no mail" do
    @user.update!(rain_threshold: 100, last_alerted_at: nil)
    client = stub_client(pop: 20)

    assert_no_emails do
      WeatherAlertJob.perform_now(@user.id, client: client)
    end
    assert_nil @user.reload.last_alerted_at
  end

  test "QA3: local hour mismatch → not selected by dispatch" do
    # 12:00 UTC == 13:00 Lagos — not 07:00
    travel_to Time.utc(2026, 10, 12, 12, 0, 0) do
      assert_equal :not_due, @user.dispatch_status
      assert_no_enqueued_jobs only: WeatherAlertJob do
        DispatchDueAlertsJob.perform_now
      end
    end
  end

  test "QA4: alerts_enabled false → not selected" do
    @user.update!(alerts_enabled: false)

    travel_to Time.utc(2026, 10, 12, 6, 0, 0) do
      assert_no_enqueued_jobs only: WeatherAlertJob do
        DispatchDueAlertsJob.perform_now
      end
    end
  end

  test "QA5: bad weather API key fails job; preferences UI still serves" do
    client = Object.new
    def client.fetch(*)
      raise WeatherClient::UnauthorizedError, "weather API unauthorized (401)"
    end

    assert_raises(WeatherClient::UnauthorizedError) do
      WeatherAlertJob.perform_now(@user.id, client: client)
    end

    sign_in_as(@user)
    get edit_preferences_path
    assert_response :success
    assert_match(/Alert preferences/, response.body)
  end

  test "QA6: preferences page works without Sidekiq (Redis restart scenario)" do
    # Web UI must not depend on the job worker being up.
    sign_in_as(@user)
    get edit_preferences_path
    assert_response :success

    patch preferences_path, params: {
      user: {
        location_label: @user.location_label,
        latitude: @user.latitude,
        longitude: @user.longitude,
        timezone: @user.timezone,
        alert_time: "07:00",
        rain_threshold: 45,
        alerts_enabled: "1"
      }
    }
    assert_redirected_to root_path
    assert_equal 45, @user.reload.rain_threshold
  end

  private

  def stub_client(pop:)
    forecast = Forecast.new(
      precipitation_probability: pop,
      summary: "qa stub",
      wind_speed: 2.0,
      raw: { "max_rain_3h_mm" => nil }
    )
    Class.new do
      define_method(:fetch) { |*_args| forecast }
    end.new
  end
end
