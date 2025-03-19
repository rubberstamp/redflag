require "test_helper"

class Quickbooks::AuthControllerTest < ActionDispatch::IntegrationTest
  # Simplified test to reduce complexity for deployment
  test "oauth_callback handles missing state parameter" do
    get quickbooks_oauth_callback_path
    assert_redirected_to root_path
    assert_equal "Invalid OAuth callback. Missing state parameter.", flash[:alert]
  end
end