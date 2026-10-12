# Public JSON for the globe explorer — current conditions by lat/lng or search.
class ConditionsController < ApplicationController
  allow_unauthenticated_access
  # Explorer clicks + landing burn through a tight cap quickly in local demos.
  rate_limit to: 180, within: 1.minute, with: -> {
    render json: { error: "Too many weather requests — wait a minute and try again" }, status: :too_many_requests
  }

  def show
    lat = params.require(:latitude)
    lon = params.require(:longitude)
    label = safe_reverse_label(lat, lon)
    conditions = CurrentWeatherClient.fetch(lat, lon, label: label)
    render json: serialize(conditions)
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue CurrentWeatherClient::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  def search
    query = params.require(:q).to_s.strip
    results = GeocodingClient.search(query, limit: 1)
    place = results.first
    unless place
      render json: { error: "No matching location" }, status: :not_found
      return
    end

    conditions = CurrentWeatherClient.fetch(place.latitude, place.longitude, label: place.label)
    render json: serialize(conditions)
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue CurrentWeatherClient::Error, GeocodingClient::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  # Full ranked city catalog + temps (cached). Client filters by zoom instantly.
  def labels
    payload = Rails.cache.fetch("conditions/labels/v2", expires_in: 15.minutes) do
      CityDirectory.reload!
      NearbyTemperaturesClient.fetch_all(CityDirectory.all).map do |label|
        {
          name: label.name,
          latitude: label.latitude,
          longitude: label.longitude,
          temperature_c: label.temperature_c,
          rank: label.rank
        }
      end
    end

    render json: { labels: payload }
  rescue NearbyTemperaturesClient::Error => e
    render json: { error: e.message, labels: [] }, status: :bad_gateway
  end

  # Kept for older clients; prefer #labels + client-side zoom filtering.
  def nearby
    lat = params.require(:latitude).to_f
    lon = params.require(:longitude).to_f
    cities = CityDirectory.nearest(lat, lon, limit: 24, max_km: 3_000)
    labels = NearbyTemperaturesClient.fetch(cities).map do |label|
      {
        name: label.name,
        latitude: label.latitude,
        longitude: label.longitude,
        temperature_c: label.temperature_c,
        rank: label.rank
      }
    end
    render json: { labels: labels, focus: { latitude: lat, longitude: lon } }
  rescue ActionController::ParameterMissing => e
    render json: { error: e.message }, status: :bad_request
  rescue NearbyTemperaturesClient::Error => e
    render json: { error: e.message, labels: [] }, status: :bad_gateway
  end

  private

  def safe_reverse_label(lat, lon)
    GeocodingClient.reverse(lat, lon)&.label
  rescue GeocodingClient::Error
    nil
  end

  def serialize(c)
    {
      latitude: c.latitude,
      longitude: c.longitude,
      label: c.label,
      temperature_c: c.temperature_c,
      feels_like_c: c.feels_like_c,
      humidity: c.humidity,
      wind_speed_ms: c.wind_speed_ms,
      wind_speed_kmh: c.wind_speed_ms ? (c.wind_speed_ms * 3.6).round(1) : nil,
      wind_deg: c.wind_deg,
      summary: c.summary,
      icon_key: c.icon_key,
      icon_url: view_context.image_path("weather/#{c.icon_key}.png"),
      observed_at: c.observed_at&.iso8601,
      fetched_at: c.fetched_at&.iso8601
    }
  end
end
