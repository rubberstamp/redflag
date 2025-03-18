require 'oauth2'
require 'qbo_api'

Rails.application.config.to_prepare do
  # Get credentials from the encrypted credentials or environment variables
  OAUTH_CLIENT_ID = Rails.application.credentials.dig(:quickbooks, :client_id) || ENV['QUICKBOOKS_CLIENT_ID'] || 'missing_client_id'
  OAUTH_CLIENT_SECRET = Rails.application.credentials.dig(:quickbooks, :client_secret) || ENV['QUICKBOOKS_CLIENT_SECRET'] || 'missing_client_secret'
  
  # Set default OAuth2 URLs
  OAUTH_SITE = "https://appcenter.intuit.com"
  OAUTH_AUTHORIZE_URL = "https://appcenter.intuit.com/connect/oauth2"
  OAUTH_TOKEN_URL = "https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer"
  OAUTH_API_BASE_URL = "https://quickbooks.api.intuit.com"
  
  # Set OAuth scopes 
  OAUTH_SCOPE = 'com.intuit.quickbooks.accounting openid profile email phone address'
  
  # Set OAuth redirect URIs
  if Rails.env.production?
    OAUTH_REDIRECT_URI = "https://redflag.fly.dev/quickbooks/oauth_callback"
  else
    OAUTH_REDIRECT_URI = "http://localhost:3000/quickbooks/oauth_callback"
  end
  
  # Create OAuth2 client
  OAUTH_CLIENT = OAuth2::Client.new(
    OAUTH_CLIENT_ID,
    OAUTH_CLIENT_SECRET,
    site: "https://oauth.platform.intuit.com",
    authorize_url: OAUTH_AUTHORIZE_URL,
    token_url: OAUTH_TOKEN_URL
  )
  
  # Log configuration details
  Rails.logger.debug "QuickBooks OAuth client configured with client_id: #{OAUTH_CLIENT_ID[0..5]}... and redirect_uri: #{OAUTH_REDIRECT_URI}"
end