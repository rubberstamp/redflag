# Postmark email configuration
if Rails.env.production?
  # Production settings
  Rails.application.config.action_mailer.delivery_method = :postmark
  Rails.application.config.action_mailer.postmark_settings = {
    api_token: ENV.fetch('POSTMARK_API_TOKEN', 'POSTMARK_API_TEST')
  }
  Rails.application.config.action_mailer.default_url_options = { 
    host: 'redflag.fly.dev', 
    protocol: 'https'
  }
elsif Rails.env.development?
  # Development settings - still use Postmark but with optional token
  Rails.application.config.action_mailer.delivery_method = :postmark
  Rails.application.config.action_mailer.postmark_settings = {
    api_token: ENV.fetch('POSTMARK_API_TOKEN', 'POSTMARK_API_TEST')
  }
  Rails.application.config.action_mailer.default_url_options = { 
    host: 'localhost', 
    port: 3000, 
    protocol: 'http'
  }
else
  # Test settings - use test mode
  Rails.application.config.action_mailer.delivery_method = :test
  Rails.application.config.action_mailer.default_url_options = { 
    host: 'localhost', 
    port: 3000, 
    protocol: 'http'
  }
end

# Common settings for all environments
Rails.application.config.action_mailer.perform_caching = false
Rails.application.config.action_mailer.raise_delivery_errors = true

# Default settings for all emails
Rails.application.config.action_mailer.default_options = {
  from: 'notifications@redflagapp.com',
  reply_to: 'support@redflagapp.com'
}