# OpenWeatherMap Geocoding API 1.0 — search cities and reverse-lookup labels.
# Keeps the API key on the server (never exposed to the browser).
class GeocodingClient
  class Error < StandardError; end
  class TimeoutError < Error; end
  class UnauthorizedError < Error; end

  BASE_URL = "https://api.openweathermap.org".freeze

  Result = Struct.new(:name, :state, :country, :latitude, :longitude, :label, keyword_init: true)

  def self.search(query, limit: 5, **opts)
    new(**opts).search(query, limit: limit)
  end

  def self.reverse(latitude, longitude, **opts)
    new(**opts).reverse(latitude, longitude)
  end

  def initialize(connection: nil, api_key: ENV["WEATHER_API_KEY"])
    @api_key = api_key
    @connection = connection || default_connection
  end

  def search(query, limit: 5)
    q = query.to_s.strip
    return [] if q.length < 2
    raise Error, "WEATHER_API_KEY is missing" if @api_key.blank?

    response = @connection.get("/geo/1.0/direct") do |req|
      req.params["q"] = q
      req.params["limit"] = limit
      req.params["appid"] = @api_key
    end
    handle_status!(response)

    Array(JSON.parse(response.body)).filter_map { |row| build_result(row) }
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    raise TimeoutError, e.message
  end

  def reverse(latitude, longitude)
    raise Error, "WEATHER_API_KEY is missing" if @api_key.blank?

    response = @connection.get("/geo/1.0/reverse") do |req|
      req.params["lat"] = latitude
      req.params["lon"] = longitude
      req.params["limit"] = 1
      req.params["appid"] = @api_key
    end
    handle_status!(response)

    row = Array(JSON.parse(response.body)).first
    row ? build_result(row) : nil
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    raise TimeoutError, e.message
  end

  private

  def default_connection
    Faraday.new(url: BASE_URL) do |f|
      f.options.timeout = 8
      f.options.open_timeout = 4
      f.adapter Faraday.default_adapter
    end
  end

  def handle_status!(response)
    case response.status
    when 200 then nil
    when 401, 403 then raise UnauthorizedError, "geocoding unauthorized (#{response.status})"
    else
      raise Error, "geocoding HTTP #{response.status}"
    end
  end

  def build_result(row)
    name = row["name"].presence
    return nil if name.blank?

    state = row["state"]
    country = row["country"]
    parts = [ name, state, country ].compact
    Result.new(
      name: name,
      state: state,
      country: country,
      latitude: row["lat"].to_f,
      longitude: row["lon"].to_f,
      label: parts.join(", ")
    )
  end
end
