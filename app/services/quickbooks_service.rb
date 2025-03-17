class QuickbooksService
  attr_reader :access_token, :realm_id, :qbo_api

  def initialize(access_token:, realm_id:)
    # Validate required parameters
    raise ArgumentError, "access_token is required" if access_token.blank?
    raise ArgumentError, "realm_id is required" if realm_id.blank?
    
    # Convert tokens to strings and ensure they're not hashes or complex objects
    token_str = access_token.is_a?(String) ? access_token : access_token.to_s
    
    # If token looks like a Hash or complex object (contains curly braces), raise an error
    if token_str.include?('{') || token_str.include?('}')
      raise ArgumentError, "access_token appears to be in an invalid format"
    end
    
    @access_token = token_str
    @realm_id = realm_id
    # We don't store refresh_token or expires_at here as QboApi doesn't use them
    
    # Log initialization for debugging
    Rails.logger.debug "QuickbooksService initialized with realm_id: #{realm_id}"
    Rails.logger.debug "Access token class: #{token_str.class}, length: #{token_str.length}"
    Rails.logger.debug "First/last chars of token: #{token_str[0..5]}...#{token_str[-6..-1]}"
    
    # Initialize the qbo_api client with the token
    # QboApi only accepts access_token and realm_id
    @qbo_api = QboApi.new(
      access_token: token_str,
      realm_id: realm_id
    )
    
    # Skip detailed logging - Faraday::Response::Logger middleware isn't available
    # Log request/response data through other means if needed in the future
  end

  # Verify if we have sufficient permissions before attempting data retrieval
  # Returns an array: [has_permissions, error_message]
  def verify_permissions(force_check = false)
    Rails.logger.debug "Verifying QuickBooks permissions..."
    error_message = nil
    
    begin
      # Check company info as a basic permissions test
      company_info = @qbo_api.get(:companyinfo, 1)
      
      if company_info.present?
        Rails.logger.info "Successfully verified QuickBooks permissions for #{company_info['CompanyName']}"
        return [true, nil]
      else
        error_message = "Failed to access QuickBooks company information. Please check your permissions."
        Rails.logger.error "Permission verification failed: Unable to retrieve company info"
      end
    rescue OAuth2::Error => e
      Rails.logger.error "Permission verification failed with OAuth error: #{e.message}"
      
      if e.message.include?("unauthorized_client")
        error_message = "Your QuickBooks account lacks the necessary permissions. Please disconnect and reconnect with full permissions."
      elsif e.message.include?("invalid_token")
        error_message = "Your QuickBooks authorization has expired. Please reconnect your account."
      else
        error_message = "QuickBooks permission error: #{e.message.split(';').first}"
      end
    rescue => e
      Rails.logger.error "Error checking permissions: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      if e.message.include?("AuthenticationFailed")
        error_message = "QuickBooks authentication failed. Please reconnect your account."
      elsif e.message.include?("Forbidden") || e.message.include?("insufficient")
        error_message = "Your QuickBooks account has insufficient permissions. Please disconnect and reconnect with full permissions."
      elsif e.message.include?("ApplicationAuthorizationFailed") || e.message.include?("003100")
        error_message = "QuickBooks API authorization failed (Error 003100). This error typically means you're missing specific permissions. Please disconnect and reconnect with full permissions."
      else
        error_message = "Error verifying QuickBooks permissions: #{e.message.split(';').first}"
      end
    end
    
    return [false, error_message || "Unable to verify QuickBooks permissions. Please reconnect with full permissions."]
  end
  
  # A basic test to verify QuickBooks connectivity
  def test_connectivity
    begin
      # Test the connection with a simple query
      company_info = @qbo_api.get(:companyinfo, 1)
      
      if company_info.present?
        Rails.logger.debug "Successfully connected to QuickBooks for company: #{company_info['CompanyName']}"
        return true
      else
        Rails.logger.error "No company info returned from QuickBooks query"
        return false
      end
    rescue => e
      Rails.logger.error "Error testing QuickBooks connectivity: #{e.message}"
      return false
    end
  end

  # Fetch transactions from QuickBooks
  def fetch_transactions(start_date, end_date)
    Rails.logger.debug "Fetching QuickBooks transactions from #{start_date} to #{end_date}"
    
    # First verify permissions
    has_permissions, error_message = verify_permissions
    unless has_permissions
      Rails.logger.error "Unable to fetch transactions due to permission issues: #{error_message}"
      return []
    end
    
    # Format dates for the query
    start_date_str = start_date.strftime('%Y-%m-%d')
    end_date_str = end_date.strftime('%Y-%m-%d')
    
    all_transactions = []
    
    # Fetch purchases (bills, credit card expenses, etc.)
    begin
      purchases = fetch_purchases(start_date_str, end_date_str)
      all_transactions.concat(purchases)
      Rails.logger.debug "Fetched #{purchases.length} purchases"
    rescue => e
      Rails.logger.error "Error fetching purchases: #{e.message}"
    end
    
    # Fetch payments
    begin
      payments = fetch_payments(start_date_str, end_date_str)
      all_transactions.concat(payments)
      Rails.logger.debug "Fetched #{payments.length} payments"
    rescue => e
      Rails.logger.error "Error fetching payments: #{e.message}"
    end
    
    # Fetch invoices
    begin
      invoices = fetch_invoices(start_date_str, end_date_str)
      all_transactions.concat(invoices)
      Rails.logger.debug "Fetched #{invoices.length} invoices"
    rescue => e
      Rails.logger.error "Error fetching invoices: #{e.message}"
    end
    
    # Fetch bank deposits
    begin
      deposits = fetch_deposits(start_date_str, end_date_str)
      all_transactions.concat(deposits)
      Rails.logger.debug "Fetched #{deposits.length} deposits"
    rescue => e
      Rails.logger.error "Error fetching deposits: #{e.message}"
    end
    
    Rails.logger.info "Fetched a total of #{all_transactions.length} transactions"
    return all_transactions
  end
  
  private
  
  # Fetch purchase transactions (bills, expenses)
  def fetch_purchases(start_date, end_date)
    purchases = []
    
    # Fetch bills
    begin
      bills_query = "SELECT * FROM Bill WHERE TxnDate >= '#{start_date}' AND TxnDate <= '#{end_date}' MAXRESULTS 1000"
      bills = @qbo_api.query(bills_query)
      
      if bills.present?
        bills.each do |bill|
          purchases << {
            id: bill["Id"],
            type: "Bill",
            date: bill["TxnDate"],
            amount: bill["TotalAmt"],
            vendor_id: bill["VendorRef"]&.[]("value"),
            vendor_name: bill["VendorRef"]&.[]("name"),
            memo: bill["PrivateNote"],
            line_items: parse_line_items(bill["Line"])
          }
        end
      end
    rescue => e
      Rails.logger.error "Error fetching bills: #{e.message}"
    end
    
    # Fetch purchase transactions (credit card expenses, etc.)
    begin
      purchases_query = "SELECT * FROM Purchase WHERE TxnDate >= '#{start_date}' AND TxnDate <= '#{end_date}' MAXRESULTS 1000"
      purchases_data = @qbo_api.query(purchases_query)
      
      if purchases_data.present?
        purchases_data.each do |purchase|
          purchases << {
            id: purchase["Id"],
            type: "Purchase",
            date: purchase["TxnDate"],
            amount: purchase["TotalAmt"],
            vendor_id: purchase["EntityRef"]&.[]("value"),
            vendor_name: purchase["EntityRef"]&.[]("name"),
            memo: purchase["PrivateNote"],
            payment_type: purchase["PaymentType"],
            line_items: parse_line_items(purchase["Line"])
          }
        end
      end
    rescue => e
      Rails.logger.error "Error fetching purchases: #{e.message}"
    end
    
    return purchases
  end
  
  # Fetch payment transactions
  def fetch_payments(start_date, end_date)
    payments = []
    
    begin
      payments_query = "SELECT * FROM Payment WHERE TxnDate >= '#{start_date}' AND TxnDate <= '#{end_date}' MAXRESULTS 1000"
      payments_data = @qbo_api.query(payments_query)
      
      if payments_data.present?
        payments_data.each do |payment|
          payments << {
            id: payment["Id"],
            type: "Payment",
            date: payment["TxnDate"],
            amount: payment["TotalAmt"],
            customer_id: payment["CustomerRef"]&.[]("value"),
            customer_name: payment["CustomerRef"]&.[]("name"),
            memo: payment["PrivateNote"],
            payment_method: payment["PaymentMethodRef"]&.[]("name")
          }
        end
      end
    rescue => e
      Rails.logger.error "Error fetching payments: #{e.message}"
    end
    
    return payments
  end
  
  # Fetch invoice transactions
  def fetch_invoices(start_date, end_date)
    invoices = []
    
    begin
      invoices_query = "SELECT * FROM Invoice WHERE TxnDate >= '#{start_date}' AND TxnDate <= '#{end_date}' MAXRESULTS 1000"
      invoices_data = @qbo_api.query(invoices_query)
      
      if invoices_data.present?
        invoices_data.each do |invoice|
          invoices << {
            id: invoice["Id"],
            type: "Invoice",
            date: invoice["TxnDate"],
            due_date: invoice["DueDate"],
            amount: invoice["TotalAmt"],
            customer_id: invoice["CustomerRef"]&.[]("value"),
            customer_name: invoice["CustomerRef"]&.[]("name"),
            memo: invoice["PrivateNote"],
            line_items: parse_line_items(invoice["Line"])
          }
        end
      end
    rescue => e
      Rails.logger.error "Error fetching invoices: #{e.message}"
    end
    
    return invoices
  end
  
  # Fetch bank deposit transactions
  def fetch_deposits(start_date, end_date)
    deposits = []
    
    begin
      deposits_query = "SELECT * FROM Deposit WHERE TxnDate >= '#{start_date}' AND TxnDate <= '#{end_date}' MAXRESULTS 1000"
      deposits_data = @qbo_api.query(deposits_query)
      
      if deposits_data.present?
        deposits_data.each do |deposit|
          deposits << {
            id: deposit["Id"],
            type: "Deposit",
            date: deposit["TxnDate"],
            amount: deposit["TotalAmt"],
            memo: deposit["PrivateNote"],
            account_id: deposit["DepositToAccountRef"]&.[]("value"),
            account_name: deposit["DepositToAccountRef"]&.[]("name"),
            line_items: parse_line_items(deposit["Line"])
          }
        end
      end
    rescue => e
      Rails.logger.error "Error fetching deposits: #{e.message}"
    end
    
    return deposits
  end
  
  # Parse line items from a transaction
  def parse_line_items(lines)
    return [] unless lines.present?
    
    line_items = []
    lines.each do |line|
      # Skip detail type Header
      next if line["DetailType"] == "Header"
      
      # Based on the line detail type, extract information
      detail_type = line["DetailType"]
      item_name = nil
      account_name = nil
      amount = line["Amount"]
      description = line["Description"]
      
      case detail_type
      when "SalesItemLineDetail"
        detail = line["SalesItemLineDetail"]
        item_name = detail["ItemRef"]["name"] if detail["ItemRef"].present?
      when "ItemBasedExpenseLineDetail"
        detail = line["ItemBasedExpenseLineDetail"]
        item_name = detail["ItemRef"]["name"] if detail["ItemRef"].present?
      when "AccountBasedExpenseLineDetail"
        detail = line["AccountBasedExpenseLineDetail"]
        account_name = detail["AccountRef"]["name"] if detail["AccountRef"].present?
      when "DepositLineDetail"
        detail = line["DepositLineDetail"]
        account_name = detail["AccountRef"]["name"] if detail["AccountRef"].present?
      end
      
      line_items << {
        detail_type: detail_type,
        amount: amount,
        description: description,
        item_name: item_name,
        account_name: account_name
      }
    end
    
    return line_items
  end
end