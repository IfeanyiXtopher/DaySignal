require "test_helper"

class UserDispatchTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  test "due when local hour matches and not yet alerted" do
    travel_to Time.utc(2026, 10, 12, 6, 0, 0) do
      assert_equal :due, @user.dispatch_status
    end
  end

  test "already_alerted when last_alerted_at is same local date" do
    zone = ActiveSupport::TimeZone["Africa/Lagos"]
    @user.update!(last_alerted_at: zone.local(2026, 10, 12, 7, 1, 0))

    travel_to Time.utc(2026, 10, 12, 6, 45, 0) do
      assert_equal :already_alerted, @user.dispatch_status
    end
  end

  test "due again on the next local day" do
    zone = ActiveSupport::TimeZone["Africa/Lagos"]
    @user.update!(last_alerted_at: zone.local(2026, 10, 11, 7, 5, 0))

    travel_to Time.utc(2026, 10, 12, 6, 0, 0) do
      assert_equal :due, @user.dispatch_status
    end
  end
end
