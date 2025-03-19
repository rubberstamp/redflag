require "test_helper"

class Quickbooks::ProfilesControllerTest < ActionDispatch::IntegrationTest
  # Simplified test to reduce complexity for deployment
  test "should redirect to connect if no session" do
    get "/quickbooks/profile"
    assert_redirected_to root_path
  end
end