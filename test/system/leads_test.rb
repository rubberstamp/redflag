require "application_system_test_case"

class LeadsTest < ApplicationSystemTestCase
  test "can submit lead form and see thank you page" do
    # Visit the homepage
    visit root_path
    
    # Find the lead form and fill it out
    fill_in "First name", with: "John"
    fill_in "Last name", with: "Doe"
    fill_in "Business Email", with: "john.doe@example.com"
    fill_in "Company Name", with: "Acme Corp"
    select "14-Day Free Trial (No Credit Card)", from: "Select Plan"
    
    # Check terms checkbox
    check "I agree to the Terms of Service and Privacy Policy"
    
    # Submit the form
    click_on "Start Free Trial"
    
    # Verify we're on the thank you page
    assert_current_path leads_thank_you_path
    
    # Verify the key content of the thank you page
    assert_text "Thank You"
    assert_text "Account Details"
    
    # Verify the success icon is present
    assert_selector ".bg-green-100"
    
    # Verify the next steps are shown
    assert_text "Next Steps"
    assert_text "Connect Your Data"
    assert_text "Review Results"
    
    # Verify action buttons are present
    assert_link "Connect QuickBooks"
    assert_link "Go to Dashboard"
  end
  
  test "form validation prevents submission with invalid email" do
    # Visit the homepage
    visit root_path
    
    # Find the lead form
    within("form[action='#{leads_path}']") do
      # Fill in data with invalid email
      fill_in "First name", with: "John"
      fill_in "Last name", with: "Doe"
      fill_in "Business Email", with: "not-an-email"
      fill_in "Company Name", with: "Acme Corp"
      select "14-Day Free Trial (No Credit Card)", from: "Select Plan"
      
      # Check terms checkbox
      check "I agree to the Terms of Service and Privacy Policy"
      
      # Submit the form - this should be blocked by browser validation
      click_on "Start Free Trial"
    end
    
    # We should still be on the home page
    assert_current_path root_path
    
    # The email field should be invalid
    assert_selector "input[type=email]:invalid"
  end
end