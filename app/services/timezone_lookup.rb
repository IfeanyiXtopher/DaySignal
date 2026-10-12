# Resolve IANA timezone from lat/long via Open-Meteo (no API key).
class TimezoneLookup
  class Error < StandardError; end

  BASE_URL = "https://api.open-meteo.com".freeze

  def self.call(latitude, longitude, connection: nil)
    new(connection: connection).call(latitude, longitude)
  end

  def initialize(connection: nil)
    @connection = connection || default_connection
  end

  def call(latitude, longitude)
    response = @connection.get("/v1/forecast") do |req|
      req.params["latitude"] = latitude
      req.params["longitude"] = longitude
      req.params["current"] = "temperature_2m"
      req.params["timezone"] = "auto"
    end

    raise Error, "timezone lookup HTTP #{response.status}" unless response.status == 200

    body = JSON.parse(response.body)
    tz = body["timezone"].to_s
    raise Error, "timezone missing" if tz.blank?
    raise Error, "unknown timezone #{tz}" unless ActiveSupport::TimeZone[tz]

    tz
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    raise Error, e.message
  end

  private

  def default_connection
    Faraday.new(url: BASE_URL) do |f|
      f.options.timeout = 8
      f.options.open_timeout = 4
      f.adapter Faraday.default_adapter
    end
  end
end
