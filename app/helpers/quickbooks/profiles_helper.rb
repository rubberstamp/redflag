module Quickbooks::ProfilesHelper
  # Extract and format all relevant data from the company_info hash
  # Returns a hash of structured company information
  def parse_company_info(profile)
    return {} unless profile.present? && profile.company_info.present?
    
    company_info = profile.company_info
    
    # Build a comprehensive hash with all company information
    {
      # Basic company information
      company_name: company_info["CompanyName"] || profile.company_name,
      legal_name: company_info["LegalName"],
      
      # Contact information
      email: extract_email(company_info),
      phone: extract_phone(company_info),
      website: company_info["WebAddr"]&.[]("URI"),
      
      # Address information
      address: format_company_address(company_info),
      city: company_info["CompanyAddr"]&.[]("City"),
      region: company_info["CompanyAddr"]&.[]("CountrySubDivisionCode"),
      postal_code: company_info["CompanyAddr"]&.[]("PostalCode"),
      country: company_info["CompanyAddr"]&.[]("Country"),
      
      # Business details
      tax_identifier: company_info["TaxIdentifier"],
      fiscal_year_start_month: company_info["FiscalYearStartMonth"],
      start_date: company_info["StartDate"],
      
      # Account/subscription information
      account_type: company_info["AccountingType"],
      subscription_status: company_info["SubscriptionStatus"],
      
      # Last update timestamp
      last_updated: extract_last_updated(company_info),
      
      # Raw data for debugging
      raw_data: company_info
    }
  end
  
  # Format the complete company address from CompanyAddr
  def format_company_address(company_info)
    return nil unless company_info["CompanyAddr"].present?
    
    addr = company_info["CompanyAddr"]
    address_lines = []
    
    # Collect all available address lines
    ["Line1", "Line2", "Line3", "Line4", "Line5"].each do |line|
      address_lines << addr[line] if addr[line].present?
    end
    
    address_lines.join(", ")
  end
  
  # Format the full address including city, region, postal code, country
  def format_full_address(company_info)
    return nil unless company_info["CompanyAddr"].present?
    
    addr = company_info["CompanyAddr"]
    parts = []
    
    # Add the street address
    address_lines = []
    ["Line1", "Line2", "Line3", "Line4", "Line5"].each do |line|
      address_lines << addr[line] if addr[line].present?
    end
    parts << address_lines.join(", ") if address_lines.any?
    
    # Add city and region together
    city_region = []
    city_region << addr["City"] if addr["City"].present?
    city_region << addr["CountrySubDivisionCode"] if addr["CountrySubDivisionCode"].present?
    parts << city_region.join(", ") if city_region.any?
    
    # Add postal code and country
    parts << addr["PostalCode"] if addr["PostalCode"].present?
    parts << addr["Country"] if addr["Country"].present?
    
    parts.join(", ")
  end
  
  # Extract email from various possible formats
  def extract_email(company_info)
    if company_info["Email"].present?
      if company_info["Email"].is_a?(Hash) && company_info["Email"]["Address"].present?
        return company_info["Email"]["Address"]
      elsif company_info["Email"].is_a?(String)
        return company_info["Email"]
      end
    end
    nil
  end
  
  # Extract phone from various possible formats
  def extract_phone(company_info)
    if company_info["PrimaryPhone"].present?
      if company_info["PrimaryPhone"].is_a?(Hash) && company_info["PrimaryPhone"]["FreeFormNumber"].present?
        return company_info["PrimaryPhone"]["FreeFormNumber"]
      elsif company_info["PrimaryPhone"].is_a?(String)
        return company_info["PrimaryPhone"]
      end
    end
    nil
  end
  
  # Extract last updated timestamp
  def extract_last_updated(company_info)
    if company_info["MetaData"].present? && company_info["MetaData"]["CreateTime"].present?
      Time.parse(company_info["MetaData"]["CreateTime"]) rescue Time.current
    else
      nil
    end
  end
  
  # Return a formatted display of company type
  def company_type_display(company_info)
    account_type = company_info["AccountingType"]
    return "Unknown" unless account_type.present?
    
    case account_type
    when "Accrual"
      "Accrual Accounting"
    when "Cash"
      "Cash-Based Accounting"
    when "None"
      "No Specific Accounting Type"
    else
      account_type
    end
  end
end
