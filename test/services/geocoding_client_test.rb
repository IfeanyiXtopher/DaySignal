require "test_helper"

class GeocodingClientTest < ActiveSupport::TestCase
  test "search normalizes OpenWeatherMap geo results" do
    body = [
      {
        "name" => "Lagos",
        "lat" => 6.5244,
        "lon" => 3.3792,
        "country" => "NG",
        "state" => "Lagos"
      }
    ].to_json

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("/geo/1.0/direct") { [ 200, { "Content-Type" => "application/json" }, body ] }
    conn = Faraday.new(url: GeocodingClient::BASE_URL) { |f| f.adapter(:test, stubs) }

    results = GeocodingClient.search("Lagos", connection: conn, api_key: "test")
    assert_equal 1, results.size
    assert_equal "Lagos, Lagos, NG", results.first.label
    assert_in_delta 6.5244, results.first.latitude, 0.0001
  end

  test "search returns empty for blank query without calling API" do
    assert_equal [], GeocodingClient.search(" ", api_key: "test")
  end
end
