require "application_system_test_case"

class LeadCaptureSystemTest < ApplicationSystemTestCase
  test "initial email capture form on homepage" do
    visit root_path
    
    # Check that the initial capture form exists
    assert_selector "form#initial-lead-form"
    assert_selector "input#email"
    
    # Test that the form has the correct action
    form = find("form#initial-lead-form")
    assert_equal "/leads/initial_capture", form[:action]
  end
  
  test "display of lead capture form" do
    # Create a test analysis session
    post "/test/session", params: { analysis_session_id: "test-session-id" }
    
    visit lead_capture_path
    
    # Check that the form displays correctly
    assert_selector "h2", text: "Your Report is Ready!"
    assert_selector "form[action='/leads']"
    
    # Verify all required fields are present
    assert_selector "input[name='lead[first_name]']"
    assert_selector "input[name='lead[last_name]']"
    assert_selector "input[name='lead[email]']"
    assert_selector "input[name='lead[company]']"
    assert_selector "select[name='lead[company_size]']"
    assert_selector "input[name='lead[phone]']"
    
    # Verify the form shows the report preview
    assert_selector ".bg-white.shadow", text: "Report Preview"
  end
  
  test "display of CFO consultation page" do
    # Create a test lead and set it in the session
    lead = Lead.create!(
      first_name: "System",
      last_name: "Test",
      email: "system@example.com",
      company: "Test Co"
    )
    
    post "/test/session", params: { 
      lead_id: lead.id
    }
    
    visit cfo_consultation_path
    
    # Check that the consultation page displays correctly
    assert_selector "h2", text: "Speak with a Financial Expert"
    
    # Check that the scheduling widget container exists
    assert_selector ".meetings-iframe-container"
    
    # Check that the skip button exists
    assert_selector "input[type='submit'][value='Skip to View Report']"
    
    # Check that testimonials are displayed
    assert_selector "h3", text: "Why Our Clients Love CFO Consultations"
  end
end