require "test_helper"

class AlertEvaluatorTest < ActiveSupport::TestCase
  test "below threshold does not trigger" do
    forecast = Forecast.new(
      precipitation_probability: 30,
      summary: "few clouds",
      wind_speed: 2.0,
      raw: { "max_rain_3h_mm" => nil }
    )

    decision = AlertEvaluator.call(forecast, 50, location_label: "Lagos")

    assert_not decision.trigger?
    assert_match(/30 < threshold=50/, decision.reason)
  end

  test "at threshold triggers" do
    forecast = Forecast.new(
      precipitation_probability: 50,
      summary: "light rain",
      wind_speed: 3.0,
      raw: {}
    )

    decision = AlertEvaluator.call(forecast, 50, location_label: "Lagos")

    assert decision.trigger?
    assert_equal "precipitation_probability=50 >= threshold=50", decision.reason
    assert_match(/Rain likely for Lagos: 50%/, decision.recommendation)
  end

  test "above threshold triggers" do
    forecast = Forecast.new(
      precipitation_probability: 80,
      summary: "rain",
      wind_speed: 4.0,
      raw: {}
    )

    decision = AlertEvaluator.call(forecast, 40)

    assert decision.trigger?
  end

  test "heavy precip triggers even when POP below threshold" do
    forecast = Forecast.new(
      precipitation_probability: 20,
      summary: "heavy intensity rain",
      wind_speed: 5.0,
      raw: { "max_rain_3h_mm" => 6.5 }
    )

    decision = AlertEvaluator.call(forecast, 50, location_label: "Lagos")

    assert decision.trigger?
    assert_match(/heavy_precip_mm=6.5/, decision.reason)
  end
end
