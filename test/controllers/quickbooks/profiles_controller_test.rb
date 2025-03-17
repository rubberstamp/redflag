require "test_helper"

class Quickbooks::ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "should redirect to connect if no session" do
    get quickbooks_profile_url
    assert_redirected_to root_path
  end

  test "should show profile if connected" do
    # Set up session with realm_id matching the fixture
    post session_url, params: { 
      quickbooks: { realm_id: 'test123' }
    }
    
    get quickbooks_profile_url
    assert_response :success
    assert_select 'h2', /Test User|Test/
  end
  
  test "should redirect to refresh if token expired" do
    # Set up session with realm_id matching the expired fixture
    post session_url, params: { 
      quickbooks: { realm_id: 'expired456' }
    }
    
    get quickbooks_profile_url
    assert_redirected_to quickbooks_refresh_token_path
  end
  
  test "should redirect to connect if disconnected" do
    # Set up session with realm_id matching the disconnected fixture
    post session_url, params: { 
      quickbooks: { realm_id: 'disconnected789' }
    }
    
    get quickbooks_profile_url
    assert_redirected_to root_path
  end
end
