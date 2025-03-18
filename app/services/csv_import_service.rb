class CsvImportService
  require 'csv'

  # Constants for transaction fields
  TRANSACTION_FIELDS = {
    id: 'id',
    type: 'type',
    date: 'date',
    amount: 'amount',
    vendor_name: 'vendor_name', 
    customer_name: 'customer_name',
    description: 'description',
    memo: 'memo'
  }

  # CSV Format templates
  FORMATS = {
    standard: {
      id: 'ID',
      date: 'Date',
      amount: 'Amount',
      type: 'Type',
      vendor_name: 'Vendor/Customer',
      description: 'Description'
    },
    quickbooks: {
      id: 'ID',
      date: 'Transaction Date',
      amount: 'Amount',
      type: 'Transaction Type',
      vendor_name: 'Name',
      description: 'Description',
      memo: 'Memo'
    },
    bank_export: {
      date: 'Date',
      amount: 'Amount',
      description: 'Description',
      type: 'Transaction Type'
    }
  }

  attr_reader :mapping

  def initialize(format = :standard, custom_mapping = nil)
    @mapping = custom_mapping || FORMATS[format.to_sym] || FORMATS[:standard]
  end

  def parse_file(file_path, start_date = nil, end_date = nil)
    transactions = []
    
    # Load the CSV data
    csv_data = CSV.read(file_path, headers: true)
    
    # Filter rows based on date if provided
    start_date = Date.parse(start_date) if start_date.is_a?(String)
    end_date = Date.parse(end_date) if end_date.is_a?(String)
    
    csv_data.each do |row|
      transaction = parse_row(row)
      
      # Skip if we couldn't parse a date or if it's outside our range
      next if transaction[:date].nil?
      
      # Filter by date range if specified
      if start_date && end_date
        transaction_date = transaction[:date].is_a?(Date) ? transaction[:date] : Date.parse(transaction[:date].to_s)
        next if transaction_date < start_date || transaction_date > end_date
      end
      
      transactions << transaction
    end
    
    Rails.logger.info "Parsed #{transactions.length} transactions from CSV file"
    transactions
  end
  
  def parse_data(csv_data, start_date = nil, end_date = nil)
    transactions = []
    
    # Parse CSV data
    csv = CSV.parse(csv_data, headers: true)
    
    # Filter rows based on date if provided
    start_date = Date.parse(start_date) if start_date.is_a?(String)
    end_date = Date.parse(end_date) if end_date.is_a?(String)
    
    csv.each do |row|
      transaction = parse_row(row)
      
      # Skip if we couldn't parse a date or if it's outside our range
      next if transaction[:date].nil?
      
      # Filter by date range if specified
      if start_date && end_date
        transaction_date = transaction[:date].is_a?(Date) ? transaction[:date] : Date.parse(transaction[:date].to_s)
        next if transaction_date < start_date || transaction_date > end_date
      end
      
      transactions << transaction
    end
    
    Rails.logger.info "Parsed #{transactions.length} transactions from CSV data"
    transactions
  end

  def detect_format(headers)
    formats = FORMATS.keys
    best_match = nil
    highest_score = 0
    
    formats.each do |format|
      format_headers = FORMATS[format].values
      matching_headers = format_headers & headers
      score = matching_headers.length.to_f / format_headers.length
      
      if score > highest_score
        highest_score = score
        best_match = format
      end
    end
    
    # If we have a match with at least 70% confidence
    if highest_score >= 0.7
      return best_match
    end
    
    # Otherwise return standard format
    :standard
  end
  
  private

  def parse_row(row)
    transaction = {}
    
    # For each field in our transaction schema, try to find it in the CSV
    TRANSACTION_FIELDS.each do |field, field_name|
      header = @mapping[field]
      transaction[field.to_sym] = row[header] if header && row[header]
    end
    
    # Handle date parsing
    if transaction[:date].present?
      begin
        transaction[:date] = Date.parse(transaction[:date])
      rescue
        # Leave as string if we can't parse it
      end
    end
    
    # Handle amount parsing - convert to float and handle negative values
    if transaction[:amount].present?
      amount_str = transaction[:amount].to_s.gsub(/[$,]/, '')
      
      # Check if it has explicit negative sign or (parentheses)
      is_negative = amount_str.start_with?('-') || (amount_str.start_with?('(') && amount_str.end_with?(')'))
      
      # Remove the parens if they exist
      amount_str = amount_str.gsub(/[()]/, '')
      
      # Parse the float
      begin
        amount = amount_str.to_f
        amount = -amount if is_negative && !amount_str.start_with?('-')
        transaction[:amount] = amount
      rescue
        # Leave as is if we can't parse it
      end
    end
    
    # Set a default type if none provided
    transaction[:type] ||= 'Transaction'
    
    # If no description, use memo or set a default
    transaction[:description] ||= transaction[:memo] || 'No description'
    
    # Return the parsed transaction
    transaction
  end
end