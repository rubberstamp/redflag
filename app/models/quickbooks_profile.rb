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
        
        # Get more detailed company information using the QboApi
        fetch_and_update_company_info(profile)
        
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
        # Try to get company info anyway
        fetch_and_update_company_info(profile)
        
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
      
      # Try to get company info anyway
      fetch_and_update_company_info(profile)
      
      # Try to save the profile even if we couldn't fetch user info
      if profile.save
        Rails.logger.info "Created QuickBooks profile with only connection info due to error: #{e.message}"
        return profile
      end
      return nil
    end
  end
  
  # Fetch detailed company information using the QboApi
  def self.fetch_and_update_company_info(profile)
    return unless profile.access_token.present? && profile.realm_id.present?
    
    begin
      # Create a QuickBooks service to access the QBO API
      service = QuickbooksService.new(
        access_token: profile.access_token,
        realm_id: profile.realm_id
      )
      
      # Get company info from the API
      company_info = service.qbo_api.get(:companyinfo, 1)
      
      # If we have company info, update the profile
      if company_info.present?
        Rails.logger.debug "Retrieved company info: #{company_info.inspect}"
        
        # Store the complete company info
        profile.company_info = company_info
        
        # Parse company info into profile attributes
        profile.parse_company_info
        
        # Save the updated profile
        if profile.save
          Rails.logger.info "Updated and saved profile with company info for #{profile.company_name}"
          
          # Log company details
          address_details = [
            profile.address.presence, 
            profile.city.presence, 
            profile.region.presence, 
            profile.postal_code.presence
          ].compact.join(", ")
          
          Rails.logger.info "Company details: #{profile.company_name}, #{address_details}"
          return true
        else
          Rails.logger.error "Failed to save profile with company info: #{profile.errors.full_messages.join(', ')}"
          return false
        end
      else
        Rails.logger.warn "No company info returned from QuickBooks API"
      end
    rescue => e
      Rails.logger.error "Error fetching company info: #{e.message}"
    end
    
    return false
  end
  
  # Parse company_info JSON data into profile attributes
  def parse_company_info
    return unless company_info.present?
    
    # Extract basic company information - always override with QBO data
    self.company_name = company_info['CompanyName'] if company_info['CompanyName'].present?
    self.legal_name = company_info['LegalName'] if company_info['LegalName'].present?
    
    # Get fiscal year start month
    self.fiscal_year_start_month = company_info['FiscalYearStartMonth'] if company_info['FiscalYearStartMonth'].present?
    
    # Handle email information - always override with QBO data
    if company_info['Email'].present?
      if company_info['Email'].is_a?(Hash) && company_info['Email']['Address'].present?
        self.email = company_info['Email']['Address']
      elsif company_info['Email'].is_a?(String)
        self.email = company_info['Email']
      end
    end
    
    # Handle phone information - always override with QBO data
    if company_info['PrimaryPhone'].present?
      if company_info['PrimaryPhone'].is_a?(Hash) && company_info['PrimaryPhone']['FreeFormNumber'].present?
        self.phone = company_info['PrimaryPhone']['FreeFormNumber']
      elsif company_info['PrimaryPhone'].is_a?(String)
        self.phone = company_info['PrimaryPhone']
      end
    end
    
    # Handle address information
    if company_info['CompanyAddr'].present?
      addr = company_info['CompanyAddr']
      
      # Build address from available lines
      address_lines = []
      ['Line1', 'Line2', 'Line3', 'Line4', 'Line5'].each do |line|
        address_lines << addr[line] if addr[line].present?
      end
      
      # Set address to all available lines, always override with QBO data
      self.address = address_lines.join(', ') if address_lines.any?
      
      # Set individual address components, always override with QBO data
      self.city = addr['City'] if addr['City'].present?
      self.region = addr['CountrySubDivisionCode'] || addr['Region'] if addr['CountrySubDivisionCode'].present? || addr['Region'].present?
      self.postal_code = addr['PostalCode'] if addr['PostalCode'].present?
      self.country = addr['Country'] if addr['Country'].present?
    end
    
    # Add extra metadata from company info if available
    if company_info['MetaData'].present? && company_info['MetaData']['CreateTime'].present?
      self.last_updated = Time.parse(company_info['MetaData']['CreateTime']) rescue Time.current
    end
    
    # Return self for method chaining
    self
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
  
  # Get the company name (prioritize stored field, then company_info, then profile_data)
  def company_name
    # First check the stored column
    stored_name = read_attribute(:company_name)
    return stored_name if stored_name.present?
    
    # Next check company_info for CompanyName or LegalName
    if company_info.present?
      return company_info['CompanyName'] if company_info['CompanyName'].present?
      return company_info['LegalName'] if company_info['LegalName'].present?
    end
    
    # Then check profile_data
    return profile_data&.dig('name') if profile_data&.dig('name').present?
    
    # Default fallback
    "QuickBooks Company"
  end
  
  # Get the email (prioritize stored field, then company_info, then profile_data)
  def email
    # First check the stored column
    stored_email = read_attribute(:email)
    return stored_email if stored_email.present?
    
    # Next check company_info for Email
    if company_info.present? && company_info['Email'].present?
      if company_info['Email'].is_a?(Hash) && company_info['Email']['Address'].present?
        return company_info['Email']['Address']
      elsif company_info['Email'].is_a?(String)
        return company_info['Email']
      end
    end
    
    # Then check profile_data
    return profile_data&.dig('email') if profile_data&.dig('email').present?
    
    nil
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
  
  # Get the phone number (prioritize stored field, then company_info, then profile_data)
  def phone_number
    # First check the stored column
    stored_phone = read_attribute(:phone)
    return stored_phone if stored_phone.present?
    
    # Next check company_info for PrimaryPhone
    if company_info.present? && company_info['PrimaryPhone'].present?
      if company_info['PrimaryPhone'].is_a?(Hash) && company_info['PrimaryPhone']['FreeFormNumber'].present?
        return company_info['PrimaryPhone']['FreeFormNumber']
      elsif company_info['PrimaryPhone'].is_a?(String)
        return company_info['PrimaryPhone']
      end
    end
    
    # Then check profile_data
    return profile_data&.dig('phone_number') if profile_data&.dig('phone_number').present?
    
    nil
  end
  
  # Override access_token getter to ensure it returns a string
  def access_token
    token = super
    token.is_a?(String) ? token : token.to_s if token.present?
  end
  
  # Override company_info setter to parse attributes when assigned
  def company_info=(info)
    super(info)
    parse_company_info if info.present?
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
    
    # Track if either API call was successful
    any_update_successful = false
    
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
        any_update_successful = true
      else
        Rails.logger.error "Failed to refresh profile data: #{response.status} - #{response.body}"
      end
    rescue => e
      Rails.logger.error "Error refreshing OpenID profile data: #{e.message}"
    end
    
    # Also try to update company info using the QBO API
    begin
      if self.class.fetch_and_update_company_info(self)
        any_update_successful = true
      end
    rescue => e
      Rails.logger.error "Error refreshing company info: #{e.message}"
    end
    
    # Save the updated profile if any updates were successful
    if any_update_successful
      if save
        Rails.logger.info "Successfully refreshed profile data for #{company_name}"
        return true
      else
        Rails.logger.error "Failed to save refreshed profile data: #{errors.full_messages.join(', ')}"
        return false
      end
    else
      Rails.logger.error "Failed to refresh any profile data from QuickBooks"
      return false
    end
  end
end
