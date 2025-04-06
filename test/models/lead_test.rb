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
  
  test "should validate valid phone formats" do
    valid_phones = [
      "+1 555-123-4567",
      "555-123-4567",
      "(555) 123-4567",
      "5551234567",
      "+44 20 1234 5678",
      "+1-555-123-4567"
    ]
    
    valid_phones.each do |phone|
      lead = Lead.new(
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        company: "Acme Corp",
        phone: phone
      )
      assert lead.valid?, "#{phone} should be a valid phone number"
    end
  end
  
  test "should not validate with invalid phone format" do
    invalid_phones = [
      "abc-def-ghij",
      "phone number",
      "555@123@4567"
    ]
    
    invalid_phones.each do |phone|
      lead = Lead.new(
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        company: "Acme Corp",
        phone: phone
      )
      assert_not lead.valid?, "#{phone} should be an invalid phone number"
      assert_includes lead.errors[:phone], "format is invalid"
    end
  end
  
  test "should correctly identify complete leads" do
    # Complete lead with all required info
    complete_lead = Lead.new(
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      company: "Acme Corp"
    )
    
    assert complete_lead.complete_lead?
    assert_not complete_lead.initial_capture_only?
    
    # Partial lead with only email
    partial_lead = Lead.new(
      email: "john.doe@example.com"
    )
    
    assert_not partial_lead.complete_lead?
    assert partial_lead.initial_capture_only?
    
    # Partial lead with some but not all fields
    incomplete_lead = Lead.new(
      email: "john.doe@example.com",
      first_name: "John"
    )
    
    assert_not incomplete_lead.complete_lead?
    assert incomplete_lead.initial_capture_only?
  end
end