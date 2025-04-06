require "test_helper"

class LeadCaptureFlowTest < ActionDispatch::IntegrationTest
  setup do
    # Disable PostHog tracking in tests
    Rails.application.config.posthog.instance_variable_set(:@disabled, true)
  end
  
  test "complete lead flow from email to CSV analysis" do
    # Step 1: Submit initial email to start the process
    post initial_lead_capture_path, params: { email: "test@example.com" }, as: :json
    
    # Verify email was captured and we got a lead ID
    assert_response :success
    response_data = JSON.parse(@response.body)
    assert response_data["success"]
    assert response_data["lead_id"].present?
    lead_id = response_data["lead_id"]
    
    # Step 2: Set up a simulated analysis session (normally done by CSV import process)
    # For the test, we'll create a mock analysis and session
    analysis = QuickbooksAnalysis.create!(
      session_id: "test-session-123",
      start_date: 30.days.ago,
      end_date: Date.today,
      status_progress: 100,
      status_success: true,
      source: "csv"
    )
    
    # Set up the session to simulate the analysis completion
    post "/test/session", params: { 
      analysis_session_id: "test-session-123",
      current_analysis_id: analysis.id,
      lead_id: lead_id,
      import_source: "csv"
    }
    
    # Step 3: Visit the lead capture page to complete registration
    get lead_capture_path
    assert_response :success
    
    # Step 4: Submit the complete lead information
    post leads_path, params: {
      lead: {
        email: "test@example.com", # Same email as initial capture
        first_name: "Test",
        last_name: "User",
        company: "Test Company",
        company_size: "11-50 employees",
        phone: "+1 555-123-4567",
        plan: "standard",
        newsletter: "1"
      }
    }
    
    # Should redirect to CFO consultation page
    assert_redirected_to cfo_consultation_path
    
    # Step 5: Visit the CFO consultation page
    get cfo_consultation_path
    assert_response :success
    
    # Step 6: Skip the CFO consultation and go directly to report
    post process_consultation_path, params: { schedule_consultation: "false" }
    
    # Verify the lead was updated correctly
    lead = Lead.find(lead_id)
    assert_equal "Test", lead.first_name
    assert_equal "User", lead.last_name
    assert_equal "test@example.com", lead.email
    assert_equal "Test Company", lead.company
    assert_equal "11-50 employees", lead.company_size
    assert_equal "+1 555-123-4567", lead.phone
    assert_equal false, lead.cfo_consultation
    
    # In a real flow, this would redirect to the report page
    # But in our test environment we don't have the full analysis setup
    # So we just verify it attempted to redirect to the correct place based on the source
    assert_match /\/imports\/analysis_report$/, @response.redirect_url
  end
  
  test "lead flow with QuickBooks analysis" do
    # Step 1: Submit initial email to start the process
    post initial_lead_capture_path, params: { email: "quickbooks@example.com" }, as: :json
    
    # Verify email was captured and we got a lead ID
    assert_response :success
    response_data = JSON.parse(@response.body)
    assert response_data["success"]
    assert response_data["lead_id"].present?
    lead_id = response_data["lead_id"]
    
    # Step 2: Set up a simulated QuickBooks analysis session
    # Create a profile for the test with a unique realm_id
    profile = QuickbooksProfile.create!(
      realm_id: "test-realm-#{Time.now.to_i}",
      email: "quickbooks@example.com",
      company_name: "Test QuickBooks Company",
      access_token: "test-token",
      token_expires_at: 1.day.from_now
    )
    
    # Create a mock analysis
    analysis = QuickbooksAnalysis.create!(
      quickbooks_profile_id: profile.id,
      session_id: "test-qb-session-123",
      start_date: 30.days.ago,
      end_date: Date.today,
      status_progress: 100,
      status_success: true,
      source: "quickbooks"
    )
    
    # Set up the session to simulate the analysis completion
    post "/test/session", params: { 
      analysis_session_id: "test-qb-session-123",
      current_analysis_id: analysis.id,
      lead_id: lead_id,
      quickbooks: { realm_id: "test-realm-123" }
    }
    
    # Step 3: Visit the lead capture page to complete registration
    get lead_capture_path
    assert_response :success
    
    # Step 4: Submit the complete lead information and choose to schedule a CFO consultation
    post leads_path, params: {
      lead: {
        email: "quickbooks@example.com",
        first_name: "QB",
        last_name: "User",
        company: "Test QuickBooks",
        company_size: "201-500 employees",
        phone: "+1 555-987-6543",
        plan: "professional",
        newsletter: "0"
      }
    }
    
    # Should redirect to CFO consultation page
    assert_redirected_to cfo_consultation_path
    
    # Step 5: Visit the CFO consultation page
    get cfo_consultation_path
    assert_response :success
    
    # Step 6: Choose to schedule a CFO consultation
    post process_consultation_path, params: { schedule_consultation: "true" }
    
    # Verify the lead was updated correctly
    lead = Lead.find(lead_id)
    assert_equal "QB", lead.first_name
    assert_equal "User", lead.last_name
    assert_equal "quickbooks@example.com", lead.email
    assert_equal "Test QuickBooks", lead.company
    assert_equal "201-500 employees", lead.company_size
    assert_equal true, lead.cfo_consultation
    
    # Verify it would redirect to the QuickBooks report page - full URL including hostname in tests
    assert_match /\/quickbooks\/analysis_report$/, @response.redirect_url
  end
  
  test "lead capture with existing session lead" do
    # Create a lead with only email (initial capture)
    initial_lead = Lead.create!(
      email: "existing@example.com"
    )
    
    # Set up an analysis session with this lead
    post "/test/session", params: { 
      analysis_session_id: "test-session-existing",
      current_analysis_id: "123",
      lead_id: initial_lead.id,
      import_source: "csv"
    }
    
    # Visit the lead capture page - should pre-populate with existing lead
    get lead_capture_path
    assert_response :success
    
    # Complete the lead information for the existing lead
    post leads_path, params: {
      lead: {
        email: "existing@example.com",
        first_name: "Existing",
        last_name: "User",
        company: "Existing Company",
        company_size: "51-200 employees",
        phone: "+1 555-555-5555",
        plan: "standard"
      },
      skip_cfo_consultation: "true" # Skip consultation
    }
    
    # Should try to redirect to report page
    assert_match /\/imports\/analysis_report$/, @response.redirect_url
    
    # Verify the existing lead was updated, not a new one created
    initial_lead.reload
    assert_equal "Existing", initial_lead.first_name
    assert_equal "User", initial_lead.last_name
    assert_equal "Existing Company", initial_lead.company
    assert_equal "51-200 employees", initial_lead.company_size
  end
end