require "test_helper"

class CurrentWeatherClientTest < ActiveSupport::TestCase
  setup do
    @fixture = file_fixture("openweathermap_current.json").read
  end

  test "normalizes stubbed current weather JSON" do
    client = CurrentWeatherClient.new(connection: stub_connection(200, @fixture), api_key: "test-key")
    conditions = client.fetch(6.5244, 3.3792, label: "Lagos, NG")

    assert_equal "Lagos, NG", conditions.label
    assert_in_delta 30.2, conditions.temperature_c, 0.01
    assert_equal "Few Clouds", conditions.summary
    assert_equal "fair", conditions.icon_key
  end

  test "maps rain codes to pcloudyr icon" do
    rainy = JSON.parse(@fixture)
    rainy["weather"] = [{ "id" => 500, "main" => "Rain", "description" => "light rain", "icon" => "10d" }]
    client = CurrentWeatherClient.new(connection: stub_connection(200, rainy.to_json), api_key: "test-key")

    assert_equal "pcloudyr", client.fetch(6.5, 3.3).icon_key
  end

  test "raises UnauthorizedError on 401" do
    client = CurrentWeatherClient.new(connection: stub_connection(401, "{}"), api_key: "bad")
    assert_raises(CurrentWeatherClient::UnauthorizedError) { client.fetch(6.5, 3.3) }
  end

  private

  def stub_connection(status, body)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get(CurrentWeatherClient::WEATHER_PATH) { [ status, { "Content-Type" => "application/json" }, body ] }
    Faraday.new(url: CurrentWeatherClient::BASE_URL) { |f| f.adapter(:test, stubs) }
  end
end
