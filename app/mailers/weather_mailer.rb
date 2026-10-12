# Outbound weather alert emails. Body must stay factual (location, POP, reason).
class WeatherMailer < ApplicationMailer
  def alert_email(user, forecast, decision)
    @user = user
    @forecast = forecast
    @decision = decision
    @local_date = local_date_for(user)

    mail(
      to: user.email_address,
      subject: "Weather alert for #{user.location_label} — #{@local_date}"
    )
  end

  private

  def local_date_for(user)
    zone = ActiveSupport::TimeZone[user.timezone] || Time.zone
    Time.current.in_time_zone(zone).to_date.iso8601
  end
end
