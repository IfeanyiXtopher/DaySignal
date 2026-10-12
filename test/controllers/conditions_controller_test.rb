require "test_helper"

class ConditionsControllerTest < ActionDispatch::IntegrationTest
  test "show returns current conditions JSON without auth" do
    conditions = CurrentConditions.new(
      latitude: 6.5244,
      longitude: 3.3792,
      label: "Lagos, NG",
      temperature_c: 30.2,
      feels_like_c: 34.1,
      humidity: 74,
      wind_speed_ms: 3.6,
      wind_deg: 210,
      summary: "Few Clouds",
      icon_key: "fair",
      provider_icon: "02d",
      observed_at: Time.zone.now,
      fetched_at: Time.zone.now
    )

    original_fetch = CurrentWeatherClient.method(:fetch)
    original_reverse = GeocodingClient.method(:reverse)
    CurrentWeatherClient.define_singleton_method(:fetch) { |*_args, **_kwargs| conditions }
    GeocodingClient.define_singleton_method(:reverse) { |*_args, **_kwargs| nil }

    get conditions_url, params: { latitude: 6.5244, longitude: 3.3792 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Lagos, NG", body["label"]
    assert_in_delta 30.2, body["temperature_c"], 0.01
    assert_equal "fair", body["icon_key"]
    assert_includes body["icon_url"], "weather/"
  ensure
    CurrentWeatherClient.define_singleton_method(:fetch, original_fetch) if original_fetch
    GeocodingClient.define_singleton_method(:reverse, original_reverse) if original_reverse
  end

  test "show requires coordinates" do
    get conditions_url, as: :json
    assert_response :bad_request
  end
end
