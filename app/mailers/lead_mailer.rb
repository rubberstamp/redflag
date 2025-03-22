class LeadMailer < ApplicationMailer
  # Send a welcome email to new leads
  def welcome_email(lead)
    @lead = lead
    @lead_full_name = "#{@lead.first_name} #{@lead.last_name}"
    
    # Create action data for Postmark
    mail(
      to: @lead.email,
      subject: "Welcome to RedFlag - Your Account is Ready",
      track_opens: true,
      track_links: 'HtmlAndText'
    ) do |format|
      format.html
      format.text
    end
  end
  
  # Send notification to admin when a new lead is created
  def admin_notification(lead)
    @lead = lead
    @lead_full_name = "#{@lead.first_name} #{@lead.last_name}"
    
    # Get admin email from environment variable, with fallback
    admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@redflagapp.com')
    
    mail(
      to: admin_email,
      subject: "New Lead: #{@lead_full_name} (#{@lead.plan})",
      track_opens: true
    ) do |format|
      format.html
      format.text
    end
  end
end