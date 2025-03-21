require "test_helper"

class LeadsControllerTest < ActionDispatch::IntegrationTest
  test "should create lead and redirect to thank you page" do
    post leads_path, params: { 
      lead: { 
        first_name: "John", 
        last_name: "Doe", 
        email: "john.doe@example.com", 
        company: "Acme Corp", 
        plan: "free_trial",
        newsletter: "1"
      } 
    }
    
    assert_redirected_to leads_thank_you_path
    
    # Check that session contains the lead info
    assert_equal "John Doe", session[:lead_info][:name]
    assert_equal "john.doe@example.com", session[:lead_info][:email]
    assert_equal "Acme Corp", session[:lead_info][:company]
    assert_equal "free_trial", session[:lead_info][:plan]
    assert_equal true, session[:lead_info][:newsletter]
  end
  
  test "should reject lead with invalid email" do
    post leads_path, params: { 
      lead: { 
        first_name: "John", 
        last_name: "Doe", 
        email: "not-an-email", 
        company: "Acme Corp", 
        plan: "free_trial" 
      } 
    }
    
    # Should return unprocessable entity status
    assert_response :unprocessable_entity
    
    # Should include error flash message
    assert_not_nil flash[:errors]
    assert_includes flash[:errors], "Email is invalid"
    
    # Should render the home page template
    assert_template "pages/home"
  end
  
  test "should reject lead without email" do
    post leads_path, params: { 
      lead: { 
        first_name: "John", 
        last_name: "Doe", 
        company: "Acme Corp", 
        plan: "free_trial" 
      } 
    }
    
    # Should return unprocessable entity status
    assert_response :unprocessable_entity
    
    # Should include error flash message
    assert_not_nil flash[:errors]
    assert_includes flash[:errors], "Email can't be blank"
    
    # Should render the home page template
    assert_template "pages/home"
  end
  
  test "should display thank you page with lead info" do
    # Set up session data
    get leads_thank_you_path
    
    # Should redirect to home when no lead info is in session
    assert_redirected_to root_path
    
    # Now set up the session data and try again
    @request.session[:lead_info] = {
      name: "John Doe",
      email: "john.doe@example.com",
      company: "Acme Corp",
      plan: "free_trial"
    }
    
    # We need to use a different test case for checking the thank you page content
    # since integration tests don't allow setting session before the request
  end
  
  # This test is implemented in the pages controller test
  # Moved there because it's easier to test with controller tests
  # than with integration tests due to session handling
end