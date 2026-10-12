require "test_helper"

class CityDirectoryTest < ActiveSupport::TestCase
  setup { CityDirectory.reload! }

  test "nearest returns Lagos-area cities first from Lagos focus" do
    cities = CityDirectory.nearest(6.5244, 3.3792, limit: 5, max_km: 800)
    names = cities.map(&:name)

    assert_includes names, "Lagos"
    assert cities.first.name == "Lagos" || names.include?("Ibadan")
  end

  test "cities include zoom ranks" do
    lagos = CityDirectory.all.find { |c| c.name == "Lagos" }
    assert_equal 1, lagos.rank
  end

  test "haversine is symmetric-ish for short hops" do
    a = CityDirectory.haversine_km(6.52, 3.38, 7.38, 3.95)
    b = CityDirectory.haversine_km(7.38, 3.95, 6.52, 3.38)
    assert_in_delta a, b, 0.01
    assert a.between?(80, 160)
  end
end
