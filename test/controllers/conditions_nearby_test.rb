require "test_helper"

class ConditionsNearbyTest < ActionDispatch::IntegrationTest
  test "nearby returns implanted temperature labels" do
    labels = [
      NearbyTemperaturesClient::Label.new(name: "Lagos", latitude: 6.52, longitude: 3.38, temperature_c: 29, rank: 1),
      NearbyTemperaturesClient::Label.new(name: "Ibadan", latitude: 7.38, longitude: 3.95, temperature_c: 28, rank: 3)
    ]
    original = NearbyTemperaturesClient.method(:fetch)
    NearbyTemperaturesClient.define_singleton_method(:fetch) { |*_args, **_kwargs| labels }

    get conditions_nearby_url, params: { latitude: 6.52, longitude: 3.38, altitude: 1.4 }, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["labels"].length
    assert_equal "Lagos", body["labels"].first["name"]
    assert_equal 29, body["labels"].first["temperature_c"]
  ensure
    NearbyTemperaturesClient.define_singleton_method(:fetch, original) if original
  end
end
