class CsvAnalysisJob < ApplicationJob
  queue_as :default

  def perform(file_path, start_date, end_date, detection_rules, session_id, format = "standard")
    # Parse dates if they're strings
    @start_date = start_date.is_a?(String) ? Date.parse(start_date) : start_date
    @end_date = end_date.is_a?(String) ? Date.parse(end_date) : end_date

    begin
      # Update job status
      update_status(session_id, 10, "Reading CSV file...")

      # Create service to parse CSV
      service = CsvImportService.new(format.to_sym)

      # Parse the CSV file
      transactions = service.parse_file(file_path, @start_date, @end_date)
      
      # Check if we have any transactions to analyze
      if transactions.empty?
        update_status(session_id, 100, "No transactions found in the selected date range.", false)
        return
      end

      # Update job status
      update_status(session_id, 40, "Preparing data for analysis...")

      # Standardize transactions for analysis
      standardized_transactions = transactions.map do |t|
        {
          'id' => t[:id],
          'date' => t[:date],
          'type' => t[:type],
          'description' => t[:description] || t[:memo] || 'No description',
          'amount' => t[:amount],
          'vendor_name' => t[:vendor_name] || t[:customer_name] || 'Unknown',
        }
      end

      # Update job status
      update_status(session_id, 60, "Analyzing transactions...")

      # Analyze the data for red flags
      analysis_results = analyze_transactions(standardized_transactions, detection_rules)
      
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
      
      # Find or create an analysis record
      analysis = find_or_create_analysis_for_session(session_id)
      
      # Update the analysis record
      if analysis.update(
        start_date: @start_date,
        end_date: @end_date,
        detection_rules: detection_rules.as_json,
        results: analysis_results.as_json,
        transactions_data: standardized_transactions.as_json,
        completed: true
      )
        # Update job status to completed
        update_status(session_id, 100, "Completed", true, analysis.id)
      else
        update_status(session_id, 100, "Failed to save analysis: #{analysis.errors.full_messages.join(', ')}", false)
      end
    rescue StandardError => e
      error_message = "Error analyzing CSV data: #{e.message}"
      Rails.logger.error error_message
      Rails.logger.error e.backtrace.join("\n")
      
      update_status(session_id, 100, "Error: #{error_message}", false)
    ensure
      # Clean up temporary file if it exists
      File.delete(file_path) if File.exist?(file_path) && !Rails.env.development?
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

    # Store the status in the database
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
        end_date: Date.current,
        source: "csv"
      )
  end

  def analyze_transactions(transactions, detection_rules = {})
    # Use the shared TransactionAnalyzer service
    analyzer = Analysis::TransactionAnalyzer.new(
      transactions,
      detection_rules,
      @start_date,
      @end_date
    )
    
    # Run the analysis
    results = analyzer.analyze
    
    # Add the account name to the results
    results.merge('account_name' => "CSV Import")
  end
end