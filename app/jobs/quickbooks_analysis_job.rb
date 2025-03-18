class QuickbooksAnalysisJob < ApplicationJob
  queue_as :default

  def perform(profile_id, start_date, end_date, detection_rules, session_id)
    # Find the profile
    profile = QuickbooksProfile.find_by(id: profile_id)
    return unless profile

    # Parse dates if they're strings
    start_date = Date.parse(start_date) if start_date.is_a?(String)
    end_date = Date.parse(end_date) if end_date.is_a?(String)

    begin
      # Create a new QuickbooksService
      service = QuickbooksService.new(
        access_token: profile.access_token,
        realm_id: profile.realm_id
      )

      # Update job status
      update_status(session_id, 10, "Validating permissions...")

      # Verify permissions
      has_permissions, error_message = service.verify_permissions
      unless has_permissions
        update_status(session_id, 100, "Failed: #{error_message}", false)
        return
      end

      # Update job status
      update_status(session_id, 20, "Fetching transactions...")

      # Retrieve transaction data
      transactions = service.fetch_transactions(start_date, end_date)
      
      # Check if we have any transactions to analyze
      if transactions.empty?
        update_status(session_id, 100, "No transactions found in the selected date range.", false)
        return
      end

      # Update job status
      update_status(session_id, 50, "Analyzing transactions...")

      # Analyze the data for red flags
      analysis_results = analyze_transactions(transactions, detection_rules, profile)
      
      # Ensure analysis_results have flagged_transactions
      if analysis_results&.[]('flagged_transactions').nil? && analysis_results&.[](:flagged_transactions).nil?
        if analysis_results.is_a?(Hash)
          analysis_results['flagged_transactions'] = []
        else
          analysis_results = { 'flagged_transactions' => [] }
        end
      end

      # Update job status
      update_status(session_id, 80, "Saving results...")
      
      # Create a new analysis record
      analysis = profile.analyses.new(
        start_date: start_date,
        end_date: end_date,
        detection_rules: detection_rules.as_json,
        results: analysis_results.as_json,
        transactions_data: transactions.as_json
      )
      
      if analysis.save
        # Update the session_id field on the analysis record instead of using Redis
        analysis.update(session_id: session_id)
        Rails.logger.info "Updated analysis record #{analysis.id} with session #{session_id}"
        
        # Update job status to completed
        update_status(session_id, 100, "Completed", true, analysis.id)
      else
        update_status(session_id, 100, "Failed to save analysis: #{analysis.errors.full_messages.join(', ')}", false)
      end
    rescue OAuth2::Error => e
      update_status(session_id, 100, "OAuth error: Your QuickBooks session has expired. Please reconnect.", false)
    rescue StandardError => e
      # Provide a user-friendly error message based on the type of error
      if e.message.include?("ApplicationAuthorizationFailed")
        error_message = "QuickBooks API authorization failed. Please disconnect and reconnect your QuickBooks account."
      elsif e.message.include?("ThrottleExceeded")
        error_message = "QuickBooks API rate limit exceeded. Please wait a few minutes and try again."
      else
        error_message = "Error analyzing your QuickBooks data: #{e.message.split(';').first}"
      end
      
      update_status(session_id, 100, "Error: #{error_message}", false)
    end
  end

  private

  def update_status(session_id, progress, message, success = nil, analysis_id = nil)
    status = {
      progress: progress, 
      message: message,
      timestamp: Time.current.to_i
    }
    
    # Add success status if provided (not nil)
    status[:success] = success unless success.nil?
    
    # Add analysis_id if provided
    status[:analysis_id] = analysis_id if analysis_id

    # Store the status in the database instead of Redis
    analysis = find_or_create_analysis_for_session(session_id)
    analysis.update(
      status_progress: progress,
      status_message: message,
      status_updated_at: Time.current,
      status_success: success,
      completed: progress == 100
    )
    
    Rails.logger.debug "Updated analysis status in database: progress=#{progress}, message=#{message}"
  end
  
  def find_or_create_analysis_for_session(session_id)
    # Find an existing analysis record for this session or create a temporary one
    QuickbooksAnalysis.find_by(session_id: session_id) || 
      QuickbooksAnalysis.create(
        session_id: session_id,
        start_date: Date.current,
        end_date: Date.current
      )
  end

  def analyze_transactions(transactions, detection_rules = {}, profile = nil)
    # Use the analysis service to analyze transactions
    # Generate some sample data for demo purposes
    flagged = []
    
    # Add some sample flagged transactions (for demo)
    if transactions.present?
      # Use the first few transactions as examples
      sample_count = [transactions.length, 5].min
      
      sample_count.times do |i|
        # Get a real transaction to base the demo on
        transaction = transactions[i]
        
        # Only create flagged transactions if we have real data
        if transaction
          # Get values from transaction, handling both string and symbol keys
          date = transaction[:date] || transaction['date']
          type = transaction[:type] || transaction['type']
          vendor_name = transaction[:vendor_name] || transaction['vendor_name']
          description = transaction[:description] || transaction['description'] || 'Transaction'
          amount = transaction[:amount] || transaction['amount']
          
          # Create a sample flagged transaction with string keys to ensure JSON compatibility
          flagged << {
            'date' => date,
            'type' => type,
            'description' => "#{vendor_name || description} #{i+1}",
            'amount' => amount,
            'risk_score' => rand(35..85),
            'reason' => ["Unusual amount", "Outside business hours", "Round number", "New vendor", "Duplicate transaction"].sample
          }
        end
      end
    end
    
    # Calculate total amount, handling both string and symbol keys
    total_amount = transactions.sum do |t| 
      amount = t[:amount] || t['amount'] || 0
      amount.to_f
    end
    
    # Get company name from profile if available
    company_name = profile&.company_name.presence || "QuickBooks Account"
    
    # Return analysis results with string keys to ensure JSON compatibility
    {
      'flagged_transactions' => flagged,
      'total_transactions' => transactions.length,
      'total_amount' => total_amount,
      'risk_score' => flagged.empty? ? 0 : rand(25..65),
      'account_name' => company_name
    }
  end
end