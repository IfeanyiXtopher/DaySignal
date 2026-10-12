# Proxies OpenWeatherMap raster tiles so the API key never ships to the browser.
class WeatherTilesController < ApplicationController
  allow_unauthenticated_access
  # Map zoom loads many raster tiles; keep this generous for local demos.
  rate_limit to: 600, within: 1.minute, with: -> { head :too_many_requests }

  LAYERS = {
    "temp" => "temp_new",
    "wind" => "wind_new",
    "precipitation" => "precipitation_new"
  }.freeze

  def show
    layer = LAYERS[params[:layer].to_s]
    return head :not_found unless layer

    api_key = ENV["WEATHER_API_KEY"]
    return head :service_unavailable if api_key.blank?

    z, x, y = params.require([ :z, :x, :y ])
    url = "https://tile.openweathermap.org/map/#{layer}/#{z}/#{x}/#{y}.png?appid=#{api_key}"

    response = Faraday.get(url) do |req|
      req.options.timeout = 8
      req.options.open_timeout = 4
    end

    return head :bad_gateway unless response.success?

    expires_in 10.minutes, public: true
    send_data response.body, type: "image/png", disposition: "inline"
  rescue Faraday::Error
    head :bad_gateway
  end
end
