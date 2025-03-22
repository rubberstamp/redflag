require "test_helper"

class LeadMailerTest < ActionMailer::TestCase
  test "welcome_email" do
    # Create a test lead
    lead = Lead.create!(
      first_name: "John",
      last_name: "Doe",
      email: "john@example.com",
      company: "Test Co",
      plan: "standard",
      newsletter: true
    )
    
    # Generate the email
    email = LeadMailer.welcome_email(lead)
    
    # Test the email attributes
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ["notifications@redflagapp.com"], email.from
    assert_equal ["john@example.com"], email.to
    assert_equal "Welcome to RedFlag - Your Account is Ready", email.subject
    
    # Test that the email contains the lead's name
    assert_match "John Doe", email.html_part.body.to_s
    assert_match "John Doe", email.text_part.body.to_s
  end
  
  test "admin_notification" do
    # Create a test lead
    lead = Lead.create!(
      first_name: "Jane",
      last_name: "Smith",
      email: "jane@example.com",
      company: "ACME Corp",
      plan: "premium",
      newsletter: false
    )
    
    # Generate the email
    email = LeadMailer.admin_notification(lead)
    
    # Test the email attributes
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ["notifications@redflagapp.com"], email.from
    # Use the default admin email when env var is not set
    assert_equal [ENV.fetch('ADMIN_EMAIL', 'admin@redflagapp.com')], email.to
    assert_equal "New Lead: Jane Smith (premium)", email.subject
    
    # Test that the email contains the lead's details
    assert_match "Jane Smith", email.html_part.body.to_s
    assert_match "ACME Corp", email.html_part.body.to_s
    assert_match "Premium", email.html_part.body.to_s
  end
end