class QuickbooksProfile < ApplicationRecord
  # Associations
  has_many :analyses, class_name: 'QuickbooksAnalysis', dependent: :destroy
  # Validations
  validates :realm_id, presence: true, uniqueness: true
  
  # Encrypt sensitive data (but not in test environment)
  # Prevent encryption issues by explicitly disabling in test
  if Rails.env.test?
    # Skip encryption in test
  else
    # Use encryption in other environments
    # Instead of a custom serializer, use type casting in the appropriate methods
    encrypts :access_token, deterministic: false, key: ActiveRecord::Encryption.config.primary_key
    encrypts :refresh_token, deterministic: false, key: ActiveRecord::Encryption.config.primary_key
  end
  
  # Get profile information from QuickBooks API
  def self.fetch_and_store_profile(user_id, realm_id, access_token, refresh_token, expires_at)
    # Create or find an existing profile by realm_id
    profile = find_or_initialize_by(realm_id: realm_id)
    
    # Update token information
    profile.user_id = user_id
    profile.access_token = access_token
    profile.refresh_token = refresh_token
    profile.token_expires_at = Time.at(expires_at.to_i) if expires_at.present?
    profile.connected_at = Time.current
    profile.active = true
    profile.last_connection_status = "Connected"
    
    # Create OAuth client to fetch user info
    client = OAuth2::Client.new(
      OAUTH_CLIENT_ID,
      OAUTH_CLIENT_SECRET,
      site: 'https://accounts.platform.intuit.com',
      authorize_url: 'https://appcenter.intuit.com/connect/oauth2',
      token_url: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
    )
    
    # Create token with access_token and refresh_token
    token = OAuth2::AccessToken.new(
      client,
      access_token,
      refresh_token: refresh_token,
      expires_at: expires_at
    )
    
    begin
      # Fetch user profile from QuickBooks API with maximum data
      Rails.logger.debug "Fetching profile data from QuickBooks API using token: #{access_token[0..5]}..."
      response = token.get('/v1/openid_connect/userinfo')
      
      if response.status == 200
        # Parse and store user profile data
        profile_data = JSON.parse(response.body)
        Rails.logger.debug "Received profile data keys: #{profile_data.keys.sort.join(', ')}"
        Rails.logger.debug "Profile data: #{profile_data.inspect}"
        
        # Store the complete raw profile data
        profile.profile_data = profile_data
        profile.last_updated = Time.current
        
        # Extract and store specific fields from profile_data
        profile.update_from_profile_data(profile_data)
        
        # Save the profile
        if profile.save
          Rails.logger.info "Successfully saved QuickBooks profile for realm_id: #{realm_id}"
          # Log success with available profile data
          Rails.logger.info "Profile saved with company: #{profile.company_name}, name: #{profile.full_name}, email: #{profile.email}"
          return profile
        else
          Rails.logger.error "Failed to save QuickBooks profile: #{profile.errors.full_messages.join(', ')}"
          return nil
        end
      else
        Rails.logger.error "Failed to fetch QuickBooks profile: #{response.status} - #{response.body}"
        # Try to save what we have so far
        if profile.save
          Rails.logger.info "Created partial QuickBooks profile without user info"
          return profile
        end
        return nil
      end
    rescue => e
      Rails.logger.error "Error fetching QuickBooks profile: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Try to save the profile even if we couldn't fetch user info
      if profile.save
        Rails.logger.info "Created QuickBooks profile with only connection info due to error: #{e.message}"
        return profile
      end
      return nil
    end
  end
  
  # Extract and store profile fields from the profile_data hash
  def update_from_profile_data(data = nil)
    data ||= self.profile_data
    return unless data.present?
    
    # Extract basic profile information
    self.email = data['email'] if data['email'].present?
    self.phone = data['phone_number'] if data['phone_number'].present?
    self.first_name = data['given_name'] if data['given_name'].present?
    self.last_name = data['family_name'] if data['family_name'].present?
    self.company_name = data['name'] if data['name'].present?
    
    # Extract address information if available
    if data['address'].present?
      addr = data['address']
      self.address = addr['street_address'] if addr['street_address'].present?
      self.city = addr['locality'] if addr['locality'].present?
      self.region = addr['region'] if addr['region'].present?
      self.postal_code = addr['postal_code'] if addr['postal_code'].present?
      self.country = addr['country'] if addr['country'].present?
    end
    
    # Ensure the complete profile_data is stored for future reference
    # This ensures we have all the data even if we don't have explicit fields for it
    if data != self.profile_data
      self.profile_data = data
      self.last_updated = Time.current
    end
    
    # Return self for method chaining
    self
  end
  
  # Check if token is expired
  def token_expired?
    # If no token is stored, consider it expired
    return true if access_token.blank?
    
    # If no expiration time is stored, consider it expired to be safe
    return true unless token_expires_at.present?
    
    begin
      # Parse expiration time safely
      expiry_time = token_expires_at.is_a?(Time) ? token_expires_at : Time.parse(token_expires_at.to_s)
      
      # Add a 5-minute buffer to avoid edge cases
      Rails.logger.debug "Token expires at: #{expiry_time}, Current time: #{Time.current}"
      expiry_time < (Time.current + 5.minutes)
    rescue => e
      # If we can't parse the expiration time, consider it expired
      Rails.logger.error "Error checking token expiration: #{e.message}"
      true
    end
  end
  
  # Get the company name (use stored field or profile_data as fallback)
  def company_name
    read_attribute(:company_name).presence || profile_data&.dig('name') || "QuickBooks Company"
  end
  
  # Get the email (use stored field or profile_data as fallback)
  def email
    read_attribute(:email).presence || profile_data&.dig('email')
  end
  
  # Get the full name (use stored fields or profile_data as fallback)
  def full_name
    first = first_name.presence || profile_data&.dig('given_name')
    last = last_name.presence || profile_data&.dig('family_name')
    
    if first.present? && last.present?
      "#{first} #{last}"
    elsif first.present?
      first
    elsif last.present?
      last
    else
      "QuickBooks User"
    end
  end
  
  # Get the phone number (use stored field or profile_data as fallback)
  def phone_number
    phone.presence || profile_data&.dig('phone_number')
  end
  
  # Override access_token getter to ensure it returns a string
  def access_token
    token = super
    token.is_a?(String) ? token : token.to_s if token.present?
  end
  
  # Override refresh_token getter to ensure it returns a string
  def refresh_token
    token = super
    token.is_a?(String) ? token : token.to_s if token.present?
  end
  
  # Get full address as a formatted string
  def full_address
    parts = []
    parts << address if address.present?
    
    city_region = []
    city_region << city if city.present?
    city_region << region if region.present?
    parts << city_region.join(', ') if city_region.any?
    
    parts << postal_code if postal_code.present?
    parts << country if country.present?
    
    parts.join(', ')
  end
  
  # Check if this profile has all contact information
  def complete_profile?
    email.present? && first_name.present? && last_name.present? && company_name.present?
  end
  
  # Check if this profile is currently active
  def active?
    active && access_token.present? && !token_expired?
  end
  
  # Get a human-readable status message
  def status_message
    return "Disconnected" if !active
    return "Expired Token" if token_expired?
    return "Missing Token" if access_token.blank?
    return last_connection_status if last_connection_status.present?
    return "Connected" if active?
    "Unknown"
  end
  
  # Update profile with any missing information from profile_data
  def sync_missing_fields
    # Only update fields that are currently blank/nil
    return unless profile_data.present?
    
    changes = {}
    
    # Check each field and update if missing
    changes[:email] = profile_data['email'] if email.blank? && profile_data['email'].present?
    changes[:phone] = profile_data['phone_number'] if phone.blank? && profile_data['phone_number'].present?
    changes[:first_name] = profile_data['given_name'] if first_name.blank? && profile_data['given_name'].present?
    changes[:last_name] = profile_data['family_name'] if last_name.blank? && profile_data['family_name'].present?
    changes[:company_name] = profile_data['name'] if company_name.blank? && profile_data['name'].present?
    
    # Update address fields if missing
    if profile_data['address'].present?
      addr = profile_data['address']
      changes[:address] = addr['street_address'] if address.blank? && addr['street_address'].present?
      changes[:city] = addr['locality'] if city.blank? && addr['locality'].present?
      changes[:region] = addr['region'] if region.blank? && addr['region'].present?
      changes[:postal_code] = addr['postal_code'] if postal_code.blank? && addr['postal_code'].present?
      changes[:country] = addr['country'] if country.blank? && addr['country'].present?
    end
    
    # Update if any changes were made
    update(changes) if changes.any?
    changes.keys.any?
  end
  
  # Fetch fresh profile data from QuickBooks API and update the profile
  def refresh_profile_data
    return false unless access_token.present?
    
    # Create OAuth client to fetch user info
    client = OAuth2::Client.new(
      OAUTH_CLIENT_ID,
      OAUTH_CLIENT_SECRET,
      site: 'https://accounts.platform.intuit.com',
      authorize_url: 'https://appcenter.intuit.com/connect/oauth2',
      token_url: 'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer'
    )
    
    # Create token with access_token and refresh_token
    token = OAuth2::AccessToken.new(
      client,
      access_token,
      refresh_token: refresh_token,
      expires_at: token_expires_at&.to_i
    )
    
    begin
      # Fetch user profile from QuickBooks API
      response = token.get('/v1/openid_connect/userinfo')
      
      if response.status == 200
        # Parse and store user profile data
        fresh_profile_data = JSON.parse(response.body)
        
        # Store the raw profile data and update last_updated
        self.profile_data = fresh_profile_data
        self.last_updated = Time.current
        
        # Update structured fields from profile_data
        update_from_profile_data(fresh_profile_data)
        
        # Save the updated profile
        if save
          Rails.logger.info "Successfully refreshed profile data for #{company_name}"
          return true
        else
          Rails.logger.error "Failed to save refreshed profile data: #{errors.full_messages.join(', ')}"
          return false
        end
      else
        Rails.logger.error "Failed to refresh profile data: #{response.status} - #{response.body}"
        return false
      end
    rescue => e
      Rails.logger.error "Error refreshing profile data: #{e.message}"
      return false
    end
  end
end
