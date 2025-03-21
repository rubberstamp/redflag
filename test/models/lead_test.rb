require "test_helper"

class LeadTest < ActiveSupport::TestCase
  test "should validate with valid attributes" do
    lead = Lead.new(
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      company: "Acme Corp",
      plan: "free_trial"
    )
    assert lead.valid?
    assert lead.save
    assert_equal "John Doe", lead.full_name
  end
  
  test "should not validate without email" do
    lead = Lead.new(
      first_name: "John",
      last_name: "Doe",
      company: "Acme Corp",
      plan: "free_trial"
    )
    assert_not lead.valid?
    assert_includes lead.errors[:email], "can't be blank"
  end
  
  test "should not validate with invalid email format" do
    lead = Lead.new(
      first_name: "John",
      last_name: "Doe",
      email: "not-an-email",
      company: "Acme Corp",
      plan: "free_trial"
    )
    assert_not lead.valid?
    assert_includes lead.errors[:email], "is invalid"
  end
  
  test "should accept various valid email formats" do
    valid_emails = [
      "user@example.com",
      "user.name@example.com",
      "user+tag@example.com",
      "user@subdomain.example.com"
    ]
    
    valid_emails.each do |email|
      lead = Lead.new(
        first_name: "John",
        last_name: "Doe",
        email: email,
        company: "Acme Corp",
        plan: "free_trial"
      )
      assert lead.valid?, "#{email} should be a valid email"
    end
  end
  
  test "should track newsletter opt-in" do
    lead = Lead.new(
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      company: "Acme Corp",
      plan: "free_trial",
      newsletter: true
    )
    assert lead.valid?
    assert lead.newsletter
    
    lead.newsletter = false
    assert lead.valid?
    assert_not lead.newsletter
  end
end