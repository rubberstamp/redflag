require "test_helper"

class LeadsControllerTest < ActionDispatch::IntegrationTest
  test "should create lead and redirect to thank you page" do
    assert_difference("Lead.count") do
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
    end
    
    # Get the lead we just created
    lead = Lead.last
    
    assert_redirected_to leads_thank_you_path
    
    # Check that session contains the lead info
    assert_equal "John Doe", session[:lead_info][:name]
    assert_equal "john.doe@example.com", session[:lead_info][:email]
    assert_equal "Acme Corp", session[:lead_info][:company]
    assert_equal "free_trial", session[:lead_info][:plan]
    assert_equal true, session[:lead_info][:newsletter]
    assert_equal lead.id, session[:lead_id]
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
  
  # The thank you page test is implemented in pages_controller_test.rb
  # We use ActionController::TestCase there which allows setting session data properly
end