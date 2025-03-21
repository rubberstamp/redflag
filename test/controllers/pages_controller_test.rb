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
  
  test "lead_thank_you should redirect to home without session data" do
    get leads_thank_you_path
    assert_redirected_to root_path
  end
  
  # Using ActionController::TestCase for session access
  class PagesThankYouTest < ActionController::TestCase
    tests PagesController
    
    test "lead_thank_you should display lead info from session" do
      session[:lead_info] = {
        name: "John Doe",
        email: "john.doe@example.com",
        company: "Acme Corp",
        plan: "free_trial"
      }
      
      get :lead_thank_you
      
      assert_response :success
      assert_select "h1", /Thank You, John Doe!/
      assert_select "span.font-medium.text-gray-800", "john.doe@example.com"
      assert_select "span.font-medium.text-gray-800", "Acme Corp"
      assert_select "span.font-medium.text-gray-800", "14-Day Free Trial"
    end
  end
end