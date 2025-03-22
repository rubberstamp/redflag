# Preview all emails at http://localhost:3000/rails/mailers/lead_mailer
class LeadMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/lead_mailer/welcome_email
  def welcome_email
    lead = Lead.first || Lead.create!(
      first_name: "Preview",
      last_name: "User",
      email: "preview@example.com",
      company: "Preview Company",
      plan: "free_trial",
      newsletter: true
    )
    LeadMailer.welcome_email(lead)
  end
  
  # Preview this email at http://localhost:3000/rails/mailers/lead_mailer/admin_notification
  def admin_notification
    lead = Lead.first || Lead.create!(
      first_name: "Preview",
      last_name: "User",
      email: "preview@example.com",
      company: "Preview Company",
      plan: "free_trial",
      newsletter: true
    )
    LeadMailer.admin_notification(lead)
  end
end