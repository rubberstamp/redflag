require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get home page" do
    get root_path
    assert_response :success
  end
  
  test "should get pricing page" do
    get pricing_path
    assert_response :success
  end
  
  test "should get enterprise page" do
    get enterprise_path
    assert_response :success
  end
  
  test "lead_thank_you should show default data without session data" do
    get leads_thank_you_path
    assert_response :success
    assert_select "h1", /Thank You/
  end
  
  # Using ActionController::TestCase for session access
  class PagesThankYouTest < ActionController::TestCase
    tests PagesController
    
    test "lead_thank_you should display lead info from session" do
      # Create a lead first
      lead = Lead.create!(
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        company: "Acme Corp",
        plan: "free_trial",
        newsletter: true
      )
      
      # Set session data
      session[:lead_info] = {
        name: lead.full_name,
        email: lead.email,
        company: lead.company,
        plan: lead.plan,
        newsletter: lead.newsletter
      }
      session[:lead_id] = lead.id
      
      get :lead_thank_you
      
      assert_response :success
      assert_select "h1", /Thank You, John Doe!/
      assert_select "span.font-medium.text-gray-800", "john.doe@example.com"
      assert_select "span.font-medium.text-gray-800", "Acme Corp"
      assert_select "span.font-medium.text-gray-800", "14-Day Free Trial"
    end
    
    test "lead_thank_you should display default info if session is empty" do
      get :lead_thank_you
      
      assert_response :success
      assert_select "h1", /Thank You, Guest!/
      assert_select "span.font-medium.text-gray-800", "your email"
    end
  end
end