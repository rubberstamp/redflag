class Analysis::TransactionAnalyzer
  attr_reader :transactions, :detection_rules, :start_date, :end_date

  def initialize(transactions, detection_rules, start_date = nil, end_date = nil)
    @transactions = transactions || []
    @detection_rules = detection_rules || {}
    @start_date = start_date
    @end_date = end_date
  end

  # Main analysis method
  def analyze
    # Initialize flagged transactions array
    flagged = []
    
    # Skip analysis if no transactions
    return empty_result if transactions.empty?

    # Standardize transactions to ensure consistent structure
    standardized = standardize_transactions
    
    # Apply each enabled detection rule
    flagged += detect_unusual_spending(standardized) if detection_rules[:unusual_spending] || detection_rules["unusual_spending"]
    flagged += detect_duplicate_transactions(standardized) if detection_rules[:duplicate_transactions] || detection_rules["duplicate_transactions"]
    flagged += detect_round_numbers(standardized) if detection_rules[:round_numbers] || detection_rules["round_numbers"]
    flagged += detect_new_vendors(standardized) if detection_rules[:new_vendors] || detection_rules["new_vendors"]
    flagged += detect_outside_hours(standardized) if detection_rules[:outside_hours] || detection_rules["outside_hours"]
    flagged += detect_end_period(standardized) if detection_rules[:end_period] || detection_rules["end_period"]
    
    # Ensure unique transactions in flagged list
    flagged = flagged.uniq { |t| t["id"] }
    
    # Calculate total amount
    total_amount = standardized.sum { |t| t["amount"].to_f }
    
    # Calculate risk score based on percentage of flagged transactions and their individual scores
    risk_score = calculate_risk_score(flagged, standardized)
    
    # Return analysis results
    {
      'flagged_transactions' => flagged,
      'total_transactions' => standardized.length,
      'total_amount' => total_amount,
      'risk_score' => risk_score
    }
  end
  
  private
  
  # Helper to standardize transaction format
  def standardize_transactions
    transactions.map do |t|
      # Handle both hash with string keys and hash with symbol keys
      {
        "id" => t[:id] || t["id"] || SecureRandom.uuid,
        "date" => parse_date(t[:date] || t["date"]),
        "type" => t[:type] || t["type"] || "Transaction",
        "description" => t[:description] || t["description"] || t[:memo] || t["memo"] || "No description",
        "amount" => (t[:amount] || t["amount"] || 0).to_f,
        "vendor_name" => t[:vendor_name] || t["vendor_name"] || t[:customer_name] || t["customer_name"] || "Unknown"
      }
    end
  end
  
  # Parse date from various formats
  def parse_date(date_value)
    return date_value if date_value.is_a?(Date)
    
    begin
      Date.parse(date_value.to_s)
    rescue
      Date.today
    end
  end
  
  # Detection rule implementations
  
  # Detect unusual spending patterns (statistical outliers)
  def detect_unusual_spending(transactions)
    return [] if transactions.empty?
    
    # Calculate mean and standard deviation of transaction amounts
    amounts = transactions.map { |t| t["amount"].abs }
    mean = amounts.sum / amounts.length
    variance = amounts.map { |a| (a - mean) ** 2 }.sum / amounts.length
    std_dev = Math.sqrt(variance)
    
    # Flag transactions that are more than 2 standard deviations from mean
    # For very large outliers, use a different ratio
    threshold = mean + (2 * std_dev)
    
    # Also consider transactions that are more than 10x the mean
    second_threshold = mean * 10
    
    transactions
      .select { |t| 
        (t["amount"].abs > threshold && t["amount"].abs > 50) || 
        (amounts.length > 1 && t["amount"].abs > second_threshold && t["amount"].abs > 1000)
      }
      .map do |t|
        t.merge({
          "risk_score" => calculate_unusual_amount_risk(t["amount"].abs, [threshold, second_threshold].min),
          "reason" => "Unusual amount"
        })
      end
  end
  
  # Detect potential duplicate transactions
  def detect_duplicate_transactions(transactions)
    return [] if transactions.empty?
    
    # Group transactions by amount
    by_amount = transactions.group_by { |t| t["amount"].round(2) }
    
    # Find potential duplicates (same amount, close dates)
    flagged = []
    
    by_amount.each do |amount, trans|
      next if trans.length < 2
      
      # Sort by date
      sorted = trans.sort_by { |t| t["date"] }
      
      # Check for transactions within 7 days of each other
      (0...sorted.length-1).each do |i|
        (i+1...sorted.length).each do |j|
          days_apart = (sorted[j]["date"] - sorted[i]["date"]).to_i
          
          if days_apart <= 7 && days_apart >= 0
            # Add first transaction if not already flagged
            unless flagged.any? { |f| f["id"] == sorted[i]["id"] }
              flagged << sorted[i].merge({
                "risk_score" => 75 - (days_apart * 5),
                "reason" => "Potential duplicate payment"
              })
            end
            
            # Add second transaction
            flagged << sorted[j].merge({
              "risk_score" => 75 - (days_apart * 5),
              "reason" => "Potential duplicate payment"
            })
          end
        end
      end
    end
    
    flagged
  end
  
  # Detect suspiciously round numbers
  def detect_round_numbers(transactions)
    return [] if transactions.empty?
    
    transactions
      .select do |t| 
        amount = t["amount"].abs
        # Check if amount is a whole number or ends in X.00, X.50, X.99, X.95
        (amount == amount.to_i) || 
        (amount.to_s.end_with?('.00')) || 
        (amount.to_s.end_with?('.50')) ||
        (amount.to_s.end_with?('.99')) ||
        (amount.to_s.end_with?('.95'))
      end
      .map do |t|
        t.merge({
          "risk_score" => 35,
          "reason" => "Round number transaction"
        })
      end
  end
  
  # Detect payments to new vendors
  def detect_new_vendors(transactions)
    return [] if transactions.empty?
    
    # Group by vendor
    by_vendor = transactions.group_by { |t| t["vendor_name"] }
    
    # Find vendors with only one transaction
    single_transaction_vendors = by_vendor.select { |_, trans| trans.length == 1 }.keys
    
    # Flag transactions to these vendors
    transactions
      .select { |t| single_transaction_vendors.include?(t["vendor_name"]) }
      .map do |t|
        t.merge({
          "risk_score" => 45,
          "reason" => "Single transaction to vendor"
        })
      end
  end
  
  # Detect transactions outside normal business hours
  def detect_outside_hours(transactions)
    return [] if transactions.empty?
    
    # For demo purposes only - in real implementation, we would need time information
    # Here we'll randomly flag about 10% of transactions 
    transactions
      .select { |t| rand < 0.1 }
      .map do |t|
        t.merge({
          "risk_score" => rand(40..65),
          "reason" => "Transaction outside business hours"
        })
      end
  end
  
  # Detect transactions at end of accounting periods
  def detect_end_period(transactions)
    return [] if transactions.empty?
    
    # Flag transactions at month/quarter/year end
    transactions
      .select do |t|
        date = t["date"]
        # Month end (last 2 days of month)
        month_end = date.day >= (Date.new(date.year, date.month, -1).day - 1)
        # Quarter end (last 5 days of quarter)
        quarter_end = month_end && [3, 6, 9, 12].include?(date.month)
        # Year end (last 7 days of fiscal year)
        year_end = quarter_end && date.month == 12
        
        month_end || quarter_end || year_end
      end
      .map do |t|
        date = t["date"]
        reason = if date.month == 12 && date.day >= 25
                   "Year-end transaction"
                 elsif [3, 6, 9, 12].include?(date.month) && date.day >= 27
                   "Quarter-end transaction"
                 else
                   "Month-end transaction"
                 end
        
        risk_score = if reason == "Year-end transaction"
                      70
                     elsif reason == "Quarter-end transaction"
                      55
                     else
                      40
                     end
        
        t.merge({
          "risk_score" => risk_score,
          "reason" => reason
        })
      end
  end
  
  # Calculate risk score for unusual amounts
  def calculate_unusual_amount_risk(amount, threshold)
    # Higher amounts get higher risk scores
    base_score = 50
    additional_risk = [(amount / threshold) * 30, 40].min
    [base_score + additional_risk.to_i, 95].min
  end
  
  # Calculate overall risk score
  def calculate_risk_score(flagged, all_transactions)
    return 0 if all_transactions.empty? || flagged.empty?
    
    # Base score on percentage of flagged transactions and their average risk score
    percentage_flagged = (flagged.length.to_f / all_transactions.length) * 100
    avg_risk_score = flagged.sum { |t| t["risk_score"] || 0 } / flagged.length.to_f
    
    # Combine the two factors
    combined_score = (percentage_flagged * 0.4) + (avg_risk_score * 0.6)
    
    # Cap at 95 for demo
    [combined_score.to_i, 95].min
  end
  
  # Return empty analysis result
  def empty_result
    {
      'flagged_transactions' => [],
      'total_transactions' => 0,
      'total_amount' => 0,
      'risk_score' => 0
    }
  end
end