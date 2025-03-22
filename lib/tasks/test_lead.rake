namespace :test do
  desc "Submit a test lead to verify email delivery to admin"
  task lead: :environment do
    # Create a test lead
    lead = Lead.new(
      first_name: "Test",
      last_name: "Lead",
      email: "test@example.com",
      company: "Test Company",
      plan: "free_trial",
      newsletter: true
    )
    
    if lead.save
      puts "Test lead created with ID: #{lead.id}"
      
      # Send emails
      puts "Sending welcome email to #{lead.email}..."
      welcome_email = LeadMailer.welcome_email(lead)
      welcome_email.deliver_now
      puts "Welcome email sent!"
      
      puts "Sending admin notification to #{ENV.fetch('ADMIN_EMAIL', 'admin@redflagapp.com')}..."
      admin_email = LeadMailer.admin_notification(lead)
      admin_email.deliver_now
      puts "Admin notification sent!"
      
      puts "Test complete! Check the following email addresses:"
      puts "- #{lead.email} (welcome email)"
      puts "- #{ENV.fetch('ADMIN_EMAIL', 'admin@redflagapp.com')} (admin notification)"
    else
      puts "Failed to create test lead:"
      lead.errors.full_messages.each do |message|
        puts "- #{message}"
      end
    end
  end
end