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
  
  # Tests for the new progressive lead capture flow
  
  test "should capture initial lead with just email" do
    # Post just the email for initial capture
    assert_difference('Lead.count') do
      post initial_lead_capture_path, params: { email: "initial@example.com" }, as: :json
    end
    
    # Verify response is JSON with success: true
    assert_response :success
    response_data = JSON.parse(@response.body)
    assert response_data["success"]
    assert response_data["lead_id"].present?
    
    # Verify lead was created with just email
    lead = Lead.find(response_data["lead_id"])
    assert_equal "initial@example.com", lead.email
    assert_nil lead.first_name # Should be nil since we only provided email
    
    # Verify lead ID is in session
    assert session[:lead_id].present?
  end
  
  test "should not capture initial lead with invalid email" do
    # Post an invalid email
    assert_no_difference('Lead.count') do
      post initial_lead_capture_path, params: { email: "not-an-email" }, as: :json
    end
    
    # Verify response is JSON with errors
    assert_response :unprocessable_entity
    response_data = JSON.parse(@response.body)
    assert_not response_data["success"]
    assert response_data["errors"].present?
    assert_includes response_data["errors"], "Email is invalid"
  end
  
  test "should show lead capture form" do
    # Setup an analysis session
    post "/test/session", params: { analysis_session_id: "test-analysis-123" }
    
    # Request the lead capture form
    get lead_capture_path
    
    # Verify it renders the form
    assert_response :success
    assert_select "form[action=?]", leads_path
    assert_select "input[name='lead[email]']"
    assert_select "input[name='lead[first_name]']"
    assert_select "input[name='lead[last_name]']"
    assert_select "input[name='lead[company]']"
  end
  
  test "should redirect from lead capture when no analysis is in progress" do
    # Request the lead capture form without an analysis session
    get lead_capture_path
    
    # Verify it redirects to home
    assert_redirected_to root_path
    assert_equal "Please start an analysis first.", flash[:alert]
  end
  
  test "should show CFO consultation page" do
    # Create a lead and set it in the session
    lead = Lead.create!(
      first_name: "Jane",
      last_name: "Smith",
      email: "jane@example.com",
      company: "Test Co",
      plan: "premium"
    )
    post "/test/session", params: { lead_id: lead.id }
    
    # Request the CFO consultation page
    get cfo_consultation_path
    
    # Verify it renders the page
    assert_response :success
    assert_select "h2", "Speak with a Financial Expert"
    assert_select "form[action=?]", process_consultation_path
  end
  
  test "should redirect from CFO consultation when no lead exists" do
    # Request the CFO consultation page without a lead in session
    get cfo_consultation_path
    
    # Verify it redirects to home
    assert_redirected_to root_path
    assert_equal "Please start over with the analysis process.", flash[:alert]
  end
  
  test "should process CFO consultation choice and update lead" do
    # Create a lead and set up session
    lead = Lead.create!(
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com",
      company: "ACME Corp",
      plan: "standard"
    )
    post "/test/session", params: { 
      lead_id: lead.id,
      analysis_session_id: "test-analysis-123"
    }
    
    # Process the consultation with "true" to schedule
    post process_consultation_path, params: { schedule_consultation: "true" }
    
    # Reload the lead and verify cfo_consultation was updated
    lead.reload
    assert lead.cfo_consultation
    
    # Without import_source specified, it defaults to QuickBooks path
    assert_redirected_to quickbooks_analysis_report_path
  end
  
  test "should process CFO consultation skip" do
    # Create a lead and set up session
    lead = Lead.create!(
      first_name: "Jane",
      last_name: "Smith",
      email: "jane@example.com",
      company: "Test Co",
      plan: "premium"
    )
    post "/test/session", params: { 
      lead_id: lead.id,
      analysis_session_id: "test-analysis-123"
    }
    
    # Process the consultation with "false" to skip
    post process_consultation_path, params: { schedule_consultation: "false" }
    
    # Reload the lead and verify cfo_consultation was updated
    lead.reload
    assert_not lead.cfo_consultation
    
    # Without import_source specified, it defaults to QuickBooks path
    assert_redirected_to quickbooks_analysis_report_path
  end
end