# Curated world cities for globe labels. Lower rank = visible from farther out.
class CityDirectory
  DATA_PATH = Rails.root.join("config/data/world_cities.json").freeze

  City = Struct.new(:name, :latitude, :longitude, :rank, keyword_init: true)

  def self.all
    @all ||= JSON.parse(File.read(DATA_PATH)).map do |row|
      City.new(
        name: row["name"],
        latitude: row["lat"].to_f,
        longitude: row["lng"].to_f,
        rank: (row["rank"] || 2).to_i
      )
    end
  end

  def self.reload!
    @all = nil
    all
  end

  def self.nearest(latitude, longitude, limit: 24, max_km: 8_000)
    lat = latitude.to_f
    lon = longitude.to_f

    all
      .map { |city| [ city, haversine_km(lat, lon, city.latitude, city.longitude) ] }
      .select { |(_, km)| km <= max_km }
      .sort_by { |(_, km)| km }
      .first(limit)
      .map(&:first)
  end

  def self.haversine_km(lat1, lon1, lat2, lon2)
    r = 6371.0
    dlat = (lat2 - lat1) * Math::PI / 180
    dlon = (lon2 - lon1) * Math::PI / 180
    a = Math.sin(dlat / 2)**2 +
        Math.cos(lat1 * Math::PI / 180) * Math.cos(lat2 * Math::PI / 180) * Math.sin(dlon / 2)**2
    2 * r * Math.asin([ Math.sqrt(a), 1.0 ].min)
  end
end
