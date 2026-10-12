require "test_helper"

class WeatherClientTest < ActiveSupport::TestCase
  setup do
    @fixture = file_fixture("openweathermap_forecast.json").read
    # Pin "now" so fixture dt values fall inside the 12h window.
    @now = Time.zone.at(1_760_000_400) # matches first slot dt in fixture
  end

  test "normalizes stubbed OpenWeatherMap JSON into Forecast" do
    travel_to @now do
      client = WeatherClient.new(connection: stub_connection(200, @fixture), api_key: "test-key")
      forecast = client.fetch(6.5244, 3.3792)

      assert_equal 62, forecast.precipitation_probability
      assert_equal "light rain", forecast.summary
      assert_in_delta 3.2, forecast.wind_speed, 0.01
      assert_equal 3, forecast.raw["slots_considered"]
      assert forecast.fetched_at
    end
  end

  test "raises UnauthorizedError on 401" do
    client = WeatherClient.new(connection: stub_connection(401, '{"cod":401}'), api_key: "bad")

    assert_raises(WeatherClient::UnauthorizedError) { client.fetch(6.5, 3.3) }
  end

  test "raises RateLimitError on 429" do
    client = WeatherClient.new(connection: stub_connection(429, "limit"), api_key: "test-key")

    assert_raises(WeatherClient::RateLimitError) { client.fetch(6.5, 3.3) }
  end

  test "raises TimeoutError when Faraday times out" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get(WeatherClient::FORECAST_PATH) { raise Faraday::TimeoutError, "timeout" }
    conn = Faraday.new(url: WeatherClient::BASE_URL) { |f| f.adapter(:test, stubs) }
    client = WeatherClient.new(connection: conn, api_key: "test-key")

    assert_raises(WeatherClient::TimeoutError) { client.fetch(6.5, 3.3) }
  end

  test "class fetch helper delegates" do
    travel_to @now do
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.get(WeatherClient::FORECAST_PATH) { [ 200, { "Content-Type" => "application/json" }, @fixture ] }
      conn = Faraday.new(url: WeatherClient::BASE_URL) { |f| f.adapter(:test, stubs) }

      forecast = WeatherClient.fetch(6.5, 3.3, connection: conn, api_key: "test-key")
      assert_equal 62, forecast.precipitation_probability
    end
  end

  private

  def stub_connection(status, body)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get(WeatherClient::FORECAST_PATH) do |_env|
      [ status, { "Content-Type" => "application/json" }, body ]
    end
    Faraday.new(url: WeatherClient::BASE_URL) { |f| f.adapter(:test, stubs) }
  end
end

