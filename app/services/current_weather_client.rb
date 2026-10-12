# OpenWeatherMap 2.5 /weather → CurrentConditions for the globe explorer.
# Inject `connection:` in tests so CI never hits the network.
class CurrentWeatherClient
  class Error < StandardError; end
  class TimeoutError < Error; end
  class UnauthorizedError < Error; end
  class RateLimitError < Error; end
  class UnexpectedResponseError < Error; end

  BASE_URL = "https://api.openweathermap.org".freeze
  WEATHER_PATH = "/data/2.5/weather".freeze

  def self.fetch(latitude, longitude, label: nil, **opts)
    new(**opts).fetch(latitude, longitude, label: label)
  end

  def initialize(connection: nil, api_key: ENV["WEATHER_API_KEY"], provider: ENV.fetch("WEATHER_PROVIDER", "openweathermap"))
    @api_key = api_key
    @provider = provider
    @connection = connection || default_connection
  end

  def fetch(latitude, longitude, label: nil)
    raise Error, "WEATHER_PROVIDER must be openweathermap (got #{@provider.inspect})" unless @provider == "openweathermap"
    raise Error, "WEATHER_API_KEY is missing" if @api_key.blank?

    response = @connection.get(WEATHER_PATH) do |req|
      req.params["lat"] = latitude
      req.params["lon"] = longitude
      req.params["appid"] = @api_key
      req.params["units"] = "metric"
    end

    handle_status!(response)
    normalize(JSON.parse(response.body), latitude, longitude, label)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    raise TimeoutError, e.message
  end

  private

  def default_connection
    Faraday.new(url: BASE_URL) do |f|
      f.options.timeout = 10
      f.options.open_timeout = 5
      f.adapter Faraday.default_adapter
    end
  end

  def handle_status!(response)
    case response.status
    when 200 then nil
    when 401, 403
      Rails.logger.error("[CurrentWeatherClient] unauthorized status=#{response.status}")
      raise UnauthorizedError, "weather API unauthorized (#{response.status})"
    when 429
      Rails.logger.warn("[CurrentWeatherClient] rate limited")
      raise RateLimitError, "weather API rate limited"
    else
      Rails.logger.error("[CurrentWeatherClient] unexpected status=#{response.status}")
      raise UnexpectedResponseError, "weather API HTTP #{response.status}"
    end
  end

  def normalize(payload, latitude, longitude, label)
    weather = Array(payload["weather"]).first || {}
    main = payload["main"] || {}
    wind = payload["wind"] || {}
    place = label.presence || payload.dig("name").presence || "Selected location"

    CurrentConditions.new(
      latitude: latitude.to_f,
      longitude: longitude.to_f,
      label: place,
      temperature_c: main["temp"]&.to_f&.round(1),
      feels_like_c: main["feels_like"]&.to_f&.round(1),
      humidity: main["humidity"]&.to_i,
      wind_speed_ms: wind["speed"]&.to_f,
      wind_deg: wind["deg"]&.to_i,
      summary: weather["description"].to_s.titleize.presence || "—",
      icon_key: icon_key_for(weather["id"].to_i, weather["icon"].to_s),
      provider_icon: weather["icon"],
      observed_at: payload["dt"] ? Time.zone.at(payload["dt"].to_i) : nil,
      fetched_at: Time.current
    )
  end

  # Map OWM condition codes → local brand icons in app/assets/images/weather/.
  def icon_key_for(code, owm_icon)
    return "sunny" if code.between?(800, 800)
    return "fair" if code.between?(801, 801)
    return "pcloudy" if code.between?(802, 803)
    return "cloudy" if code == 804
    return "pcloudyr" if code.between?(300, 531) || code.between?(200, 232)
    return "cloudy" if code.between?(600, 622) || code.between?(701, 781)

    owm_icon.start_with?("01") ? "sunny" : "fair"
  end
end
