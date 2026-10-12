# Per-user: fetch forecast → evaluate rules → email if triggered.
# Runs in Sidekiq — never call this from a web request synchronously in MVP.
class WeatherAlertJob < ApplicationJob
  queue_as :default

  # Missing user / soft disable: drop quietly.
  discard_on ActiveJob::DeserializationError

  # Transient weather failures: retry a few times with backoff.
  retry_on WeatherClient::TimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on WeatherClient::RateLimitError, wait: :polynomially_longer, attempts: 3

  # Bad API key / auth: fail loudly, do not spin forever.
  retry_on WeatherClient::UnauthorizedError, attempts: 1

  # SMTP / delivery problems: retry then land in Sidekiq's dead set.
  retry_on Net::SMTPError, wait: :polynomially_longer, attempts: 3
  retry_on Errno::ECONNREFUSED, wait: :polynomially_longer, attempts: 3
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3


  # client: injectable for tests (defaults to WeatherClient class).
  def perform(user_id, client: WeatherClient)
    user = User.find_by(id: user_id)
    return if user.nil?
    return unless user.alerts_enabled?
    return unless user.preferences_complete?

    forecast = client.fetch(user.latitude, user.longitude)
    decision = AlertEvaluator.call(
      forecast,
      user.rain_threshold,
      location_label: user.location_label
    )

    return unless decision.trigger?

    WeatherMailer.alert_email(user, forecast, decision).deliver_now
    user.update!(last_alerted_at: Time.current)
  end
end
