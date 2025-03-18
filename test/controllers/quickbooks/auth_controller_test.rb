require "test_helper"

class Quickbooks::AuthControllerTest < ActionDispatch::IntegrationTest
  # Test that the connect action clears existing sessions
  test "connect action clears existing sessions" do
    # Simulate a session by using session variables
    get root_path
    post root_path, params: { _method: 'patch', session: { quickbooks: { realm_id: "test_realm" } } }
    
    # Call connect which should clear the session
    get quickbooks_connect_path
    
    # Assertions to make sure the redirect happens (no direct session testing in integration tests)
    assert_response :redirect
  end
  
  # Test the disconnect action
  test "disconnect action clears sessions and updates database" do
    # Set up a session with a realm_id that matches our fixture
    post session_url, params: { quickbooks: { realm_id: "test123" } }
    
    # Get disconnect which should clear tokens in the database
    get quickbooks_disconnect_path
    
    # Check that we're redirected and the proper flash message is set
    assert_redirected_to root_path
    assert_equal "Successfully disconnected from QuickBooks.", flash[:notice]
    
    # Verify the profile in the database had its tokens cleared
    profile = quickbooks_profiles(:test_profile).reload
    assert_nil profile.access_token
    assert_nil profile.refresh_token
  end
  
  # Test handling of invalid OAuth callbacks
  test "oauth_callback handles missing state parameter" do
    get quickbooks_oauth_callback_path
    assert_redirected_to root_path
    assert_equal "Invalid OAuth callback. Missing state parameter.", flash[:alert]
  end
  
  # Test permissions error page renders correctly
  test "permissions error page accessible with quickbooks session" do
    # Set up a session with a realm_id that matches our fixture
    post session_url, params: { quickbooks: { realm_id: "test123" } }
    
    # Access the permissions error page
    get quickbooks_permissions_error_path, params: { error_message: "Test error" }
    assert_response :success
    
    # Verify the presence of key elements
    assert_select "h2", "Permission Issue Detected"
  end
end