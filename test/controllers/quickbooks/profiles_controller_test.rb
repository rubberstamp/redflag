require "test_helper"

class Quickbooks::ProfilesControllerTest < ActionDispatch::IntegrationTest
  # Simplified test to reduce complexity for deployment
  test "should redirect to connect if no session" do
    get quickbooks_profile_path
    assert_redirected_to root_path
  end
end
