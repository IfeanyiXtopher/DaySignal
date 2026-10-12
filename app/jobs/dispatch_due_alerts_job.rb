# Hourly cron entry: enqueue WeatherAlertJob only for users due in their local hour.
#
# Learning note: the server may be in UTC; we always convert with the user's timezone.
class DispatchDueAlertsJob < ApplicationJob
  queue_as :default

  def perform(now: Time.current)
    enqueued = 0

    User.alerts_enabled.find_each do |user|
      case user.dispatch_status(now: now)
      when :due
        WeatherAlertJob.perform_later(user.id)
        enqueued += 1
      when :invalid_timezone
        Rails.logger.error(
          "[DispatchDueAlertsJob] skip user_id=#{user.id} invalid timezone=#{user.timezone.inspect}"
        )
      end
      # :not_due / :already_alerted / :incomplete — silent skip
    end

    Rails.logger.info("[DispatchDueAlertsJob] enqueued=#{enqueued} at=#{now.iso8601}")
    enqueued
  end
end
