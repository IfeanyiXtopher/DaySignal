require "test_helper"

class GeocodingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "search is public for the globe explorer" do
    sign_out
    fake = [
      GeocodingClient::Result.new(
        name: "Lagos",
        state: "Lagos",
        country: "NG",
        latitude: 6.52,
        longitude: 3.38,
        label: "Lagos, Lagos, NG"
      )
    ]
    original = GeocodingClient.method(:search)
    GeocodingClient.define_singleton_method(:search) { |*_args, **_kwargs| fake }

    get geocode_path, params: { q: "Lagos" }, as: :json
    assert_response :success
  ensure
    GeocodingClient.define_singleton_method(:search, original) if original
  end

  test "search returns json results from stubbed client" do
    fake = [
      GeocodingClient::Result.new(
        name: "Lagos",
        state: "Lagos",
        country: "NG",
        latitude: 6.52,
        longitude: 3.38,
        label: "Lagos, Lagos, NG"
      )
    ]
    original = GeocodingClient.method(:search)
    GeocodingClient.define_singleton_method(:search) { |*_args, **_kwargs| fake }

    get geocode_path, params: { q: "Lagos" }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Lagos, Lagos, NG", body["results"].first["label"]
  ensure
    GeocodingClient.define_singleton_method(:search, original) if original
  end
end
