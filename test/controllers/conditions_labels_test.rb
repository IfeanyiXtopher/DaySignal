require "test_helper"

class ConditionsLabelsTest < ActionDispatch::IntegrationTest
  test "labels returns ranked catalog for client-side zoom filtering" do
    labels = [
      NearbyTemperaturesClient::Label.new(name: "Lagos", latitude: 6.52, longitude: 3.38, temperature_c: 29, rank: 1),
      NearbyTemperaturesClient::Label.new(name: "Ikeja", latitude: 6.60, longitude: 3.35, temperature_c: 30, rank: 4)
    ]
    original = NearbyTemperaturesClient.method(:fetch_all)
    NearbyTemperaturesClient.define_singleton_method(:fetch_all) { |*_args, **_kwargs| labels }
    Rails.cache.clear

    get conditions_labels_url, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body["labels"].length
    assert_equal 1, body["labels"].first["rank"]
    assert_equal "Lagos", body["labels"].first["name"]
  ensure
    NearbyTemperaturesClient.define_singleton_method(:fetch_all, original) if original
    Rails.cache.clear
  end
end
