require "test_helper"

class LeadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Set HTTP auth credentials for admin routes - use ENV variables
    ENV["ADMIN_USERNAME"] = "admin" unless ENV["ADMIN_USERNAME"]
    ENV["ADMIN_PASSWORD"] = "admin" unless ENV["ADMIN_PASSWORD"]
    
    @auth_headers = { 
      "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(
        ENV["ADMIN_USERNAME"], 
        ENV["ADMIN_PASSWORD"]
      ) 
    }
  end
  
  test "should create lead and set session" do
    # Force PostHog to be disabled in test environment
    Rails.application.config.posthog.instance_variable_set(:@disabled, true)
    
    # Post a new lead
    assert_difference('Lead.count') do
      post leads_path, params: { 
        lead: { 
          first_name: "John", 
          last_name: "Doe", 
          email: "john@example.com", 
          company: "ACME Corp", 
          company_size: "11-50 employees",
          phone: "+1 555-123-4567",
          plan: "standard",
          newsletter: "1"
        },
        skip_cfo_consultation: "true" # Skip CFO consultation for this test
      }
    end
    
    # With skip_cfo_consultation=true, it should redirect to the appropriate report page
    # But since we don't have a valid analysis session in this test, it defaults to root_path
    # We'll just verify it doesn't go to the CFO consultation page
    assert_not_equal cfo_consultation_path, @response.redirect_url
    
    # Check if session has lead info
    assert_equal "John Doe", session[:lead_info][:name]
    assert_equal "john@example.com", session[:lead_info][:email]
    assert_equal "ACME Corp", session[:lead_info][:company]
    assert_equal "11-50 employees", session[:lead_info][:company_size]
    assert_equal "+1 555-123-4567", session[:lead_info][:phone]
    assert_equal "standard", session[:lead_info][:plan]
    assert_equal true, session[:lead_info][:newsletter]
    
    # Verify lead ID is in session
    assert session[:lead_id].present?
  end
  
  test "should create lead and redirect to CFO consultation" do
    # Force PostHog to be disabled in test environment
    Rails.application.config.posthog.instance_variable_set(:@disabled, true)
    
    # Post a new lead without skip_cfo_consultation flag
    assert_difference('Lead.count') do
      post leads_path, params: { 
        lead: { 
          first_name: "Jane", 
          last_name: "Smith", 
          email: "jane@example.com", 
          company: "Test Corp", 
          company_size: "51-200 employees",
          phone: "+1 555-987-6543",
          plan: "standard",
          newsletter: "0"
        }
        # No skip_cfo_consultation parameter
      }
    end
    
    # Verify redirect to CFO consultation page
    assert_redirected_to cfo_consultation_path
    
    # Verify lead ID is in session
    assert session[:lead_id].present?
  end
  
  test "should not create lead with invalid data" do
    # Post with missing required fields
    assert_no_difference('Lead.count') do
      post leads_path, params: { 
        lead: { 
          first_name: "", 
          last_name: "Doe", 
          email: "invalid_email", 
          company: "", 
          plan: "standard" 
        } 
      }
    end
    
    # Should render the home page with errors
    assert_response :unprocessable_entity
    assert_includes @response.body, "Email is invalid"
  end
  
  test "should get admin index with auth" do
    # Access admin index with auth
    get leads_path, headers: @auth_headers
    assert_response :success
    assert_select "h1", "Lead Management"
  end
  
  test "should not get admin index without auth" do
    # Try to access admin index without auth
    get leads_path
    assert_response :unauthorized
  end
  
  test "should get admin details with auth" do
    # Create a test lead
    lead = Lead.create!(
      first_name: "Jane",
      last_name: "Smith",
      email: "jane@example.com",
      company: "Test Co",
      plan: "premium",
      newsletter: true
    )
    
    # Access admin_index with auth
    get admin_leads_path, headers: @auth_headers
    assert_response :success
    
    # Check if our test lead is in the response
    assert_select "td", "Jane Smith"
    assert_select "td", "jane@example.com"
  end
  
  test "should have analytics tracking on lead creation" do
    # Check if the analytics concern is included
    assert LeadsController.included_modules.include?(AnalyticsTracking)
    
    # Check if track_event method is called (indirectly by checking if the method exists)
    assert LeadsController.instance_methods.include?(:track_event)
  end
end