# Snapshot of current weather for the explorer UI (not the alert Forecast DTO).
CurrentConditions = Struct.new(
  :latitude,
  :longitude,
  :label,
  :temperature_c,
  :feels_like_c,
  :humidity,
  :wind_speed_ms,
  :wind_deg,
  :summary,
  :icon_key,
  :provider_icon,
  :observed_at,
  :fetched_at,
  keyword_init: true
)
