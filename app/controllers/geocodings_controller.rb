# JSON helpers for preferences + public globe explorer search.
class GeocodingsController < ApplicationController
  allow_unauthenticated_access only: %i[search reverse]
  rate_limit to: 90, within: 1.minute, only: %i[search reverse], with: -> {
    render json: { error: "Too many search requests — wait a minute and try again" }, status: :too_many_requests
  }

  def search
    results = GeocodingClient.search(params[:q], limit: 6)
    render json: {
      results: results.map { |r| serialize(r) }
    }
  rescue GeocodingClient::Error => e
    render json: { error: e.message, results: [] }, status: :bad_gateway
  end

  def reverse
    lat = params.require(:latitude)
    lon = params.require(:longitude)
    place = GeocodingClient.reverse(lat, lon)
    timezone = safe_timezone(lat, lon)

    if place
      render json: serialize(place).merge(timezone: timezone)
    else
      render json: {
        label: "Pinned location",
        latitude: lat.to_f,
        longitude: lon.to_f,
        timezone: timezone
      }
    end
  rescue GeocodingClient::Error => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

  def serialize(result)
    {
      label: result.label,
      name: result.name,
      state: result.state,
      country: result.country,
      latitude: result.latitude,
      longitude: result.longitude
    }
  end

  def safe_timezone(lat, lon)
    TimezoneLookup.call(lat, lon)
  rescue TimezoneLookup::Error
    nil
  end
end
