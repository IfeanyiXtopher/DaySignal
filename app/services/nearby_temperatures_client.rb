# Batch current temperatures via Open-Meteo (no API key) for globe labels.
# Keeps OpenWeatherMap quota for click/geolocate detail panels.
class NearbyTemperaturesClient
  class Error < StandardError; end
  class TimeoutError < Error; end

  BASE_URL = "https://api.open-meteo.com".freeze
  CHUNK = 40

  Label = Struct.new(:name, :latitude, :longitude, :temperature_c, :rank, keyword_init: true)

  def self.fetch(cities, **opts)
    new(**opts).fetch(cities)
  end

  def self.fetch_all(cities, **opts)
    new(**opts).fetch_all(cities)
  end

  def initialize(connection: nil)
    @connection = connection || default_connection
  end

  def fetch_all(cities)
    Array(cities).each_slice(CHUNK).flat_map { |slice| fetch(slice) }
  end

  def fetch(cities)
    list = Array(cities)
    return [] if list.empty?

    response = @connection.get("/v1/forecast") do |req|
      req.params["latitude"] = list.map(&:latitude).join(",")
      req.params["longitude"] = list.map(&:longitude).join(",")
      req.params["current"] = "temperature_2m"
      req.params["timezone"] = "UTC"
    end

    raise Error, "Open-Meteo HTTP #{response.status}" unless response.status == 200

    payload = JSON.parse(response.body)
    rows = payload.is_a?(Array) ? payload : [ payload ]

    list.each_with_index.filter_map do |city, index|
      row = rows[index] || {}
      temp = row.dig("current", "temperature_2m")
      next if temp.nil?

      Label.new(
        name: city.name,
        latitude: city.latitude,
        longitude: city.longitude,
        temperature_c: temp.to_f.round,
        rank: city.respond_to?(:rank) ? city.rank : 2
      )
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    raise TimeoutError, e.message
  end

  private

  def default_connection
    Faraday.new(url: BASE_URL) do |f|
      f.options.timeout = 30
      f.options.open_timeout = 15
      f.adapter Faraday.default_adapter
    end
  end
end
