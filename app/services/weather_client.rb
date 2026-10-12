# Faraday client for OpenWeatherMap 2.5 forecast → Forecast DTO.
#
# Learning note: inject `connection:` in tests so CI never hits the network.
class WeatherClient
  class Error < StandardError; end
  class TimeoutError < Error; end
  class UnauthorizedError < Error; end
  class RateLimitError < Error; end
  class UnexpectedResponseError < Error; end

  BASE_URL = "https://api.openweathermap.org".freeze
  FORECAST_PATH = "/data/2.5/forecast".freeze
  WINDOW_HOURS = 12
  HEAVY_RAIN_MM = 5.0

  def self.fetch(latitude, longitude, **opts)
    new(**opts).fetch(latitude, longitude)
  end

  def initialize(connection: nil, api_key: ENV["WEATHER_API_KEY"], provider: ENV.fetch("WEATHER_PROVIDER", "openweathermap"))
    @api_key = api_key
    @provider = provider
    @connection = connection || default_connection
  end

  def fetch(latitude, longitude)
    raise Error, "WEATHER_PROVIDER must be openweathermap (got #{@provider.inspect})" unless @provider == "openweathermap"
    raise Error, "WEATHER_API_KEY is missing" if @api_key.blank?

    response = @connection.get(FORECAST_PATH) do |req|
      req.params["lat"] = latitude
      req.params["lon"] = longitude
      req.params["appid"] = @api_key
      req.params["units"] = "metric"
    end

    handle_status!(response)
    normalize(JSON.parse(response.body))
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
    when 401, 403 then raise UnauthorizedError, "weather API unauthorized (#{response.status})"
    when 429 then raise RateLimitError, "weather API rate limited"
    else
      raise UnexpectedResponseError, "weather API HTTP #{response.status}: #{response.body.to_s.truncate(200)}"
    end
  end

  def normalize(payload)
    list = Array(payload["list"])
    raise UnexpectedResponseError, "forecast list missing" if list.empty?

    now = Time.current
    window_end = now + WINDOW_HOURS.hours
    in_window = list.select do |slot|
      slot_time = Time.zone.at(slot["dt"].to_i)
      slot_time >= now - 1.hour && slot_time <= window_end
    end
    candidates = in_window.presence || [ list.first ]

    best = candidates.max_by { |slot| pop_percent(slot) }
    precip_mm = candidates.filter_map { |slot| slot.dig("rain", "3h")&.to_f }.max

    Forecast.new(
      precipitation_probability: pop_percent(best),
      summary: best.dig("weather", 0, "description").presence || "n/a",
      wind_speed: best.dig("wind", "speed")&.to_f,
      raw: {
        "window_hours" => WINDOW_HOURS,
        "slots_considered" => candidates.size,
        "max_rain_3h_mm" => precip_mm,
        "chosen_dt" => best["dt"],
        "heavy_rain_threshold_mm" => HEAVY_RAIN_MM
      },
      fetched_at: now
    )
  end

  def pop_percent(slot)
    (slot["pop"].to_f * 100).round
  end
end
