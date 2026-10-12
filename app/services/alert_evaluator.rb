# Pure Ruby rules: forecast + threshold → trigger decision. No LLM.
class AlertEvaluator
  Decision = Struct.new(:trigger, :reason, :recommendation, keyword_init: true) do
    def trigger? = trigger
  end

  HEAVY_RAIN_MM = WeatherClient::HEAVY_RAIN_MM

  def self.call(forecast, rain_threshold, location_label: nil)
    new(forecast, rain_threshold, location_label: location_label).call
  end

  def initialize(forecast, rain_threshold, location_label: nil)
    @forecast = forecast
    @rain_threshold = rain_threshold.to_i
    @location_label = location_label
  end

  def call
    pop = @forecast.precipitation_probability
    heavy_mm = @forecast.raw.is_a?(Hash) ? @forecast.raw["max_rain_3h_mm"] : nil

    if pop.nil?
      return Decision.new(
        trigger: false,
        reason: "precipitation_probability missing",
        recommendation: "No precipitation probability in forecast; no alert sent."
      )
    end

    if pop >= @rain_threshold
      return Decision.new(
        trigger: true,
        reason: "precipitation_probability=#{pop} >= threshold=#{@rain_threshold}",
        recommendation: recommendation_for(pop)
      )
    end

    if heavy_mm.present? && heavy_mm.to_f >= HEAVY_RAIN_MM
      return Decision.new(
        trigger: true,
        reason: "heavy_precip_mm=#{heavy_mm} >= #{HEAVY_RAIN_MM}",
        recommendation: recommendation_for(pop, heavy: true, heavy_mm: heavy_mm)
      )
    end

    Decision.new(
      trigger: false,
      reason: "precipitation_probability=#{pop} < threshold=#{@rain_threshold}",
      recommendation: "No alert: POP #{pop}% below threshold #{@rain_threshold}%."
    )
  end

  private

  def recommendation_for(pop, heavy: false, heavy_mm: nil)
    place = @location_label.presence || "your location"
    if heavy
      "Heavy precipitation likely for #{place}: #{heavy_mm} mm in a 3-hour slot " \
        "(POP #{pop}%). Consider adjusting outdoor plans."
    else
      "Rain likely for #{place}: #{pop}% chance of precipitation " \
        "(threshold #{@rain_threshold}%)."
    end
  end
end
