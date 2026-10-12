class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Extra IANA zones useful for this project that are not always listed in
  # ActiveSupport::TimeZone.all (lookup still works via ActiveSupport::TimeZone[]).
  EXTRA_TIMEZONES = [
    ["(GMT+01:00) Africa/Lagos", "Africa/Lagos"],
    ["(GMT+00:00) Africa/Accra", "Africa/Accra"]
  ].freeze

  validates :email_address, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  # Preference fields are optional at sign-up; required when saving the preferences form.
  with_options on: :preferences_update do
    validates :location_label, presence: true
    validates :latitude, :longitude, presence: true, numericality: true
    validates :latitude, inclusion: { in: -90.0..90.0, message: "must be between -90 and 90" }
    validates :longitude, inclusion: { in: -180.0..180.0, message: "must be between -180 and 180" }
    validates :timezone, presence: true
    validates :alert_time, presence: true
    validates :rain_threshold, presence: true,
                               numericality: { only_integer: true, in: 0..100 }
    validate :timezone_must_resolve
  end

  scope :alerts_enabled, -> { where(alerts_enabled: true) }

  def self.timezone_options
    from_rails = ActiveSupport::TimeZone.all.map { |z| [z.to_s, z.name] }
    (EXTRA_TIMEZONES + from_rails).uniq { |(_label, name)| name }.sort_by(&:first)
  end

  def preferences_complete?
    location_label.present? && latitude.present? && longitude.present? &&
      timezone.present? && alert_time.present?
  end

  # Human status line for the dashboard (Step 1.5).
  def alert_status_summary
    return "Alerts off" unless alerts_enabled?

    if preferences_complete?
      local = alert_time.strftime("%H:%M")
      "Alerts on · next window ~ #{local} (#{timezone})"
    else
      "Alerts on · finish setting your location and time"
    end
  end

  # Used by DispatchDueAlertsJob (Step 4).
  # Returns :due, :not_due, :already_alerted, :incomplete, or :invalid_timezone.
  def dispatch_status(now: Time.current)
    return :incomplete unless preferences_complete?
    return :incomplete unless alerts_enabled?

    zone = ActiveSupport::TimeZone[timezone]
    return :invalid_timezone unless zone

    local = now.in_time_zone(zone)
    return :not_due unless alert_time && local.hour == alert_time.hour
    return :already_alerted if already_alerted_on_local_date?(local.to_date, zone: zone)

    :due
  end

  # Idempotency: at most one alert evaluation email stamp per local calendar day.
  def already_alerted_on_local_date?(local_date, zone: ActiveSupport::TimeZone[timezone])
    return false if last_alerted_at.blank? || zone.nil?

    last_alerted_at.in_time_zone(zone).to_date == local_date
  end

  private

  def timezone_must_resolve
    return if timezone.blank?
    return if ActiveSupport::TimeZone[timezone]

    errors.add(:timezone, "is not a known timezone")
  end
end

