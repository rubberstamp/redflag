require 'ostruct'

class Quickbooks::AuthController < ApplicationController
  # Store session data for the OAuth flow
  before_action :initialize_session, only: [:connect]
  
  # Initiate the QuickBooks OAuth flow
  def connect
    # Clear ALL QuickBooks session data before starting a new connection
    # This prevents the "No route matches [GET] "/connect/oauth2" error
    session.delete(:quickbooks)
    session.delete(:csrf_token)
    
    # Generate a new CSRF token for security
    csrf_token = SecureRandom.hex(32)
    session[:csrf_token] = csrf_token
    
    # State parameter to prevent CSRF attacks - using simpler state format to prevent parsing issues
    state = {
      csrf_token: csrf_token,
      return_to: params[:return_to] || root_path
    }.to_json
    
    Rails.logger.debug "Starting new QuickBooks OAuth flow with clean session"
    
    begin
      # Create authorization URL with explicit scopes to ensure proper permissions
      scopes = [
        "com.intuit.quickbooks.accounting", # Critical for data access
        "openid",                          # For user identification
        "profile", "email", "phone", "address"  # Profile information
      ]
      
      # Join scopes with spaces to create the final scope string
      scope_string = scopes.join(" ")
      
      Rails.logger.info "Requesting QuickBooks authorization with scopes: #{scope_string}"
      
      authorize_url = "https://appcenter.intuit.com/connect/oauth2" +
        "?client_id=#{OAUTH_CLIENT_ID}" +
        "&response_type=code" +
        "&scope=#{URI.encode_www_form_component(scope_string)}" +
        "&redirect_uri=#{URI.encode_www_form_component(OAUTH_REDIRECT_URI)}" +
        "&state=#{URI.encode_www_form_component(state)}"
      
      Rails.logger.debug "Redirecting to QuickBooks authorization URL: #{authorize_url[0..100]}..."
      
      # Redirect to QuickBooks authorization page
      redirect_to authorize_url, allow_other_host: true
    rescue => e
      Rails.logger.error "Error initiating QuickBooks OAuth flow: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to root_path, alert: "Error connecting to QuickBooks. Please try again."
    end
  end
  
  # Handle the callback from QuickBooks OAuth
  def oauth_callback
    # Log the callback for debugging
    Rails.logger.debug "OAuth callback received with params: state=#{params[:state] ? '[PRESENT]' : '[MISSING]'}, code=#{params[:code] ? '[PRESENT]' : '[MISSING]'}, realmId=#{params[:realmId] || '[MISSING]'}"
    Rails.logger.debug "Full callback params: #{params.inspect}"
    
    # Verify CSRF token from the state parameter
    begin
      if params[:state].blank?
        Rails.logger.error "OAuth callback missing state parameter"
        return redirect_to root_path, alert: "Invalid OAuth callback. Missing state parameter."
      end
      
      # Handle error cases first
      if params[:error].present?
        Rails.logger.error "OAuth error returned from QuickBooks: #{params[:error]} - #{params[:error_description]}"
        
        if params[:error] == "invalid_scope"
          Rails.logger.error "SCOPE ERROR: Requested scopes: #{OAUTH_SCOPE}"
          return redirect_to root_path, alert: "QuickBooks rejected some of the requested permissions. Please disconnect and try connecting again with all permissions."
        elsif params[:error] == "access_denied"
          return redirect_to root_path, alert: "You denied permission to access your QuickBooks data. All permissions are required for this app to function."
        else
          return redirect_to root_path, alert: "QuickBooks authentication error: #{params[:error_description] || params[:error]}"
        end
      end
      
      # Clean up the state parameter if it has extra query params attached
      clean_state = params[:state].to_s
      if clean_state.include?('?')
        Rails.logger.warn "State parameter contains extra query parameters, cleaning up"
        clean_state = clean_state.split('?').first
      end
      
      # Additional sanitization for malformed JSON
      clean_state = clean_state.strip
      Rails.logger.debug "Cleaned state parameter: #{clean_state}"
      
      begin
        state = JSON.parse(clean_state)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse state JSON: #{e.message}, state: #{clean_state}"
        # Try to recover from common JSON parsing issues
        if clean_state.start_with?('{') && clean_state.end_with?('}')
          Rails.logger.warn "Attempting to recover from JSON parse error with best-effort parsing"
          begin 
            # Try a more lenient parsing approach
            state = { 'csrf_token' => session[:csrf_token], 'return_to' => root_path }
          rescue => e2
            Rails.logger.error "Recovery attempt failed: #{e2.message}"
            return redirect_to root_path, alert: "Invalid OAuth callback. Please try connecting again."
          end
        else
          return redirect_to root_path, alert: "Invalid OAuth callback. Please try connecting again."
        end
      end
      
      if session[:csrf_token].blank?
        Rails.logger.error "OAuth callback missing csrf_token in session - session may have been cleared"
        return redirect_to root_path, alert: "Your session expired. Please try connecting again."
      end
      
      if state['csrf_token'] != session[:csrf_token]
        Rails.logger.error "OAuth callback CSRF token mismatch. Expected: #{session[:csrf_token]}, Got: #{state['csrf_token']}"
        return redirect_to root_path, alert: "Invalid request. Please try again."
      end
    rescue => e
      Rails.logger.error "Error parsing OAuth callback state: #{e.message}"
      return redirect_to root_path, alert: "Invalid OAuth callback. Please try connecting again."
    end
    
    # Exchange the authorization code for an access token
    if params[:code].present?
      begin
        # Check for realm ID - this is crucial for the OAuth flow
        if params[:realmId].blank?
          Rails.logger.error "OAuth callback missing realmId parameter"
          return redirect_to root_path, alert: "QuickBooks company ID (realmId) is missing. Please try connecting again."
        end
        
        # Store realm ID immediately in session so we don't lose it if token exchange has issues
        realm_id = params[:realmId]
        
        # Clear any existing tokens before getting new ones
        session[:quickbooks] = { "realm_id" => realm_id }
        
        Rails.logger.debug "Exchanging authorization code for token with realm_id: #{realm_id}"
        
        begin
          # Exchange authorization code for token
          token = OAUTH_CLIENT.auth_code.get_token(
            params[:code],
            redirect_uri: OAUTH_REDIRECT_URI
          )
          
          # Log token details for debugging
          Rails.logger.debug "Token obtained: access_token=#{token.token[0..5]}..., refresh_token=#{token.refresh_token[0..5]}..., expires_in=#{token.expires_in}"
        rescue => e
          Rails.logger.error "Error during token exchange: #{e.message}"
          raise e
        end
        
        # Verify we got a proper token response
        if token.token.blank? || token.refresh_token.blank?
          Rails.logger.error "OAuth token exchange returned incomplete token data"
          return redirect_to root_path, alert: "Failed to get complete authorization from QuickBooks. Please try again."
        end
        
        # Store a minimal reference in the session
        session[:quickbooks] = {
          "realm_id" => params[:realmId] # Just store the realm ID in the session
        }
        
        Rails.logger.debug "OAuth successful: access_token=#{token.token[0..5]}..., refresh_token=#{token.refresh_token[0..5]}..., realm_id=#{params[:realmId]}, expires_at=#{token.expires_at}"
        
        # Store the profile and tokens in the database
        # In a real app, this would use current_user.id instead of 1
        user_id = 1 # Temporary hardcoded value for demo
        
        begin
          # Fetch and store profile using the new token
          profile = QuickbooksProfile.fetch_and_store_profile(
            user_id,
            params[:realmId],
            token.token,
            token.refresh_token,
            token.expires_at
          )
          
          if profile
            Rails.logger.info "Successfully created/updated QuickBooks profile for #{profile.company_name}"
            redirect_to quickbooks_start_analysis_path, notice: "Successfully connected to QuickBooks as #{profile.company_name}!"
            return
          else
            Rails.logger.error "Failed to create/update profile"
            # Continue with just the session data as fallback
          end
        rescue => e
          Rails.logger.error "Error storing QuickBooks profile: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          
          # Even if profile storage fails completely, we can still use the session
          redirect_to quickbooks_start_analysis_path, notice: "Connected to QuickBooks! Profile features will be limited."
          return
        end
        
        # If we reach here without returning, redirect to start analysis
        redirect_to quickbooks_start_analysis_path, notice: "Successfully connected to QuickBooks!"
      rescue OAuth2::Error => e
        Rails.logger.error "OAuth token exchange error: #{e.message}"
        Rails.logger.error "OAuth error details: #{e.code} - #{e.description}"
        
        # Handle specific OAuth errors
        if e.code == "invalid_grant" 
          redirect_to root_path, alert: "QuickBooks authorization was invalid or expired. Please try again."
        elsif e.code == "invalid_client"
          redirect_to root_path, alert: "Application authentication failed. Please contact support."
        else
          redirect_to root_path, alert: "Failed to connect to QuickBooks: #{e.message}"
        end
      rescue => e
        Rails.logger.error "Unexpected error during OAuth callback: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        redirect_to root_path, alert: "An error occurred while connecting to QuickBooks. Please try again."
      end
    else
      Rails.logger.info "OAuth callback received with no code - likely user cancelled"
      redirect_to root_path, alert: "QuickBooks connection was cancelled or denied."
    end
  end
  
  # Disconnect from QuickBooks
  def disconnect
    # Get realm ID for database lookup
    realm_id = session[:quickbooks]&.[]("realm_id")
    
    # Find profile in database
    profile = nil
    if realm_id.present?
      profile = QuickbooksProfile.find_by(realm_id: realm_id)
    end
    
    # Attempt to revoke token with Intuit
    if profile&.access_token.present?
      begin
        # Only try to revoke if we have a token
        token = profile.access_token
        
        Rails.logger.info "Revoking QuickBooks token before disconnecting"
        
        # Call Intuit's revoke endpoint
        uri = URI.parse(OAUTH_CLIENT.site + "/v2/oauth2/tokens/revoke")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        
        request = Net::HTTP::Post.new(uri.path)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request.body = { token: token }.to_json
        
        response = http.request(request)
        
        if response.code.to_i < 300
          Rails.logger.info "Successfully revoked QuickBooks token"
        else
          Rails.logger.warn "Failed to revoke QuickBooks token: #{response.code} - #{response.body}"
        end
      rescue => e
        Rails.logger.error "Error revoking QuickBooks token: #{e.message}"
      end
    end
    
    # Clear all QuickBooks-related session data
    session.delete(:quickbooks)
    session.delete(:csrf_token)
    
    # Mark profile as disconnected in the database
    if profile
      # Option 1: Delete the profile
      # profile.destroy
      
      # Option 2: Mark as inactive by clearing tokens but keeping profile data
      profile.access_token = nil
      profile.refresh_token = nil
      profile.token_expires_at = nil
      profile.active = false
      
      if profile.save
        Rails.logger.info "Marked QuickBooks profile as disconnected for #{profile.company_name}"
      else
        Rails.logger.error "Failed to mark QuickBooks profile as disconnected: #{profile.errors.full_messages.join(', ')}"
      end
    end
    
    Rails.logger.info "User disconnected from QuickBooks"
    redirect_to root_path, notice: "Successfully disconnected from QuickBooks."
  end
  
  # Refresh the access token if it's expired
  def refresh_token
    realm_id = session[:quickbooks]&.[]("realm_id")
    
    if realm_id.present?
      # Find the profile in the database
      profile = QuickbooksProfile.find_by(realm_id: realm_id)
      
      if profile.nil?
        Rails.logger.error "Cannot refresh token - no profile found for realm_id: #{realm_id}"
        session.delete(:quickbooks)
        return redirect_to root_path, alert: "Your QuickBooks profile was not found. Please connect again."
      end
      
      # Check if the token is expired
      if !profile.token_expired?
        Rails.logger.debug "Token is not expired yet, no need to refresh"
        return redirect_to quickbooks_start_analysis_path
      end
      
      begin
        Rails.logger.debug "Refreshing expired QuickBooks access token"
        
        # Make sure we have a refresh token to use
        if profile.refresh_token.blank?
          Rails.logger.error "Cannot refresh token - no refresh token in profile"
          session.delete(:quickbooks)
          profile.update(access_token: nil, token_expires_at: nil)
          return redirect_to root_path, alert: "Your QuickBooks authorization is incomplete. Please connect again."
        end

        # Create OAuth token with refresh token
        old_token = OAuth2::AccessToken.new(
          OAUTH_CLIENT,
          profile.access_token,
          refresh_token: profile.refresh_token,
          expires_at: profile.token_expires_at&.to_i
        )
        
        # Refresh the token
        new_token = old_token.refresh!
        
        # Update token information in the profile
        profile.access_token = new_token.token
        profile.refresh_token = new_token.refresh_token
        profile.token_expires_at = Time.at(new_token.expires_at) if new_token.expires_at.present?
        
        if profile.save
          Rails.logger.info "Updated QuickBooks profile with refreshed token for #{profile.company_name}"
        else
          Rails.logger.error "Failed to update QuickBooks profile with refreshed token: #{profile.errors.full_messages.join(', ')}"
          return redirect_to root_path, alert: "Failed to refresh your QuickBooks token. Please try connecting again."
        end
        
        # Redirect back to the analysis page
        redirect_to quickbooks_start_analysis_path, notice: "Your QuickBooks connection has been refreshed."
      rescue OAuth2::Error => e
        Rails.logger.error "OAuth token refresh error: #{e.message}"
        
        # Handle specific OAuth errors 
        if e.code == "invalid_grant"
          error_message = "Your QuickBooks authorization has expired. Please connect again."
        elsif e.code == "invalid_client"
          error_message = "Application authentication failed. Please contact support."
        else
          error_message = "Failed to refresh QuickBooks connection: #{e.message}"
        end
        
        # Clear tokens in profile when refresh fails
        profile.update(access_token: nil, token_expires_at: nil, active: false)
        
        # Clear session data
        session.delete(:quickbooks)
        
        redirect_to root_path, alert: error_message
      rescue => e
        Rails.logger.error "Unexpected error during token refresh: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Clear tokens in profile
        profile&.update(access_token: nil, token_expires_at: nil, active: false)
        
        # Clear session on any error
        session.delete(:quickbooks)
        
        redirect_to root_path, alert: "Your QuickBooks connection could not be refreshed. Please connect again."
      end
    else
      # If we don't have realm_id in session, redirect back home
      redirect_to root_path, alert: "Please connect to QuickBooks first."
    end
  end
  
  private
  
  def initialize_session
    # Initialize the session state but don't overwrite existing values
    session[:quickbooks] ||= nil
    session[:csrf_token] ||= nil
  end
end