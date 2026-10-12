# Normalized weather snapshot used by AlertEvaluator (provider-agnostic).
class Forecast
  attr_reader :precipitation_probability, :summary, :wind_speed, :raw, :fetched_at

  def initialize(precipitation_probability:, summary:, wind_speed:, raw:, fetched_at: Time.current)
    @precipitation_probability = precipitation_probability
    @summary = summary
    @wind_speed = wind_speed
    @raw = raw
    @fetched_at = fetched_at
  end
end
