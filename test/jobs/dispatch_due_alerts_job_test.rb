require "test_helper"

class DispatchDueAlertsJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @lagos = users(:one) # Africa/Lagos, alert 07:00
    @nairobi = users(:two) # Nairobi, alert 08:00
  end

  test "enqueues Lagos user when local hour is 07:00" do
    # Africa/Lagos is UTC+1 → 06:00 UTC == 07:00 Lagos
    travel_to Time.utc(2026, 10, 12, 6, 5, 0) do
      assert_enqueued_with(job: WeatherAlertJob, args: [ @lagos.id ]) do
        DispatchDueAlertsJob.perform_now
      end
    end
  end

  test "does not enqueue when local hour does not match" do
    # 08:00 UTC == 09:00 Lagos — not 07:00
    travel_to Time.utc(2026, 10, 12, 8, 0, 0) do
      assert_no_enqueued_jobs only: WeatherAlertJob do
        DispatchDueAlertsJob.perform_now
      end
    end
  end

  test "does not enqueue disabled users" do
    @lagos.update!(alerts_enabled: false)

    travel_to Time.utc(2026, 10, 12, 6, 0, 0) do
      assert_no_enqueued_jobs only: WeatherAlertJob do
        DispatchDueAlertsJob.perform_now
      end
    end
  end

  test "does not double-enqueue after already alerted same local day" do
    # Stamp as already alerted earlier the same Lagos morning
    zone = ActiveSupport::TimeZone["Africa/Lagos"]
    @lagos.update!(last_alerted_at: zone.local(2026, 10, 12, 7, 10, 0))

    travel_to Time.utc(2026, 10, 12, 6, 30, 0) do
      assert_no_enqueued_jobs only: WeatherAlertJob do
        DispatchDueAlertsJob.perform_now
      end
    end
  end

  test "skips invalid timezone without raising" do
    @lagos.update_columns(timezone: "Mars/Phobos")

    travel_to Time.utc(2026, 10, 12, 6, 0, 0) do
      assert_nothing_raised do
        assert_no_enqueued_jobs only: WeatherAlertJob do
          DispatchDueAlertsJob.perform_now
        end
      end
    end
  end

  test "enqueues Nairobi at its local 08:00, not Lagos" do
    # Nairobi is UTC+3 → 05:00 UTC == 08:00 Nairobi; Lagos local is 06:00 (not due)
    travel_to Time.utc(2026, 10, 12, 5, 0, 0) do
      assert_equal :not_due, @lagos.dispatch_status
      assert_equal :due, @nairobi.dispatch_status

      assert_enqueued_with(job: WeatherAlertJob, args: [ @nairobi.id ]) do
        DispatchDueAlertsJob.perform_now
      end
    end
  end
end

