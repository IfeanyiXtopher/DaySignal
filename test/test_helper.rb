ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Single process: parallel workers + pg gem segfaulted on this machine.
    # Re-enable with `parallelize(workers: :number_of_processors)` if CI is fine.
    parallelize(workers: 1)


    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
