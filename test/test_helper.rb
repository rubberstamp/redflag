ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Don't load fixtures by default due to foreign key issues
    # fixtures :all
    
    # Initialize fixture variables to avoid errors
    @@already_loaded_fixtures = {}
    
    # Skip fixtures setup to avoid foreign key issues
    def setup_fixtures(*); end
    
    # Skip fixtures teardown to avoid errors
    def teardown_fixtures(*); end

    # Add more helper methods to be used by all tests here...
  end
end

# Helper methods for integration tests to simulate sessions
class ActionDispatch::IntegrationTest
  # Skip fixtures for integration tests too
  self.use_transactional_tests = false
  
  def setup
    # Skip fixture loading
    ActiveRecord::FixtureSet.reset_cache
  end
  
  # Helper method to simulate setting a session
  def setup_session(hash)
    post "/test/session", params: hash
  end
  
  # Helper method to simulate setting a QuickBooks session
  def setup_quickbooks_session(realm_id)
    setup_session(quickbooks: { realm_id: realm_id })
  end
end
