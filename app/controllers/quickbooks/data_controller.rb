class Quickbooks::DataController < ApplicationController
  before_action :ensure_quickbooks_connected
  
  # Start the data analysis process
  def start_analysis
    # Directly render the form if we hit persistent issues
    if params[:skip_validation] == 'true'
      Rails.logger.info "Skipping service validation, rendering analysis form directly"
      return render 'quickbooks/data/start_analysis'
    end
    
    # Get the QuickBooks service
    service = quickbooks_service
    
    # If service creation fails, quickbooks_service already handled the redirect
    return if service.nil?
    
    # Check permissions
    begin
      has_permissions, error_message = service.verify_permissions
      unless has_permissions
        @error_message = error_message
        return redirect_to quickbooks_permissions_error_path(error_message: error_message)
      end
    rescue => e
      Rails.logger.error "Permission check failed: #{e.message}"
      flash[:alert] = "Unable to verify QuickBooks permissions: #{e.message}"
      # Continue to render the form even if permission check fails
      return render 'quickbooks/data/start_analysis'
    end
    
    # Only show the analysis form if we have sufficient permissions
    render 'quickbooks/data/start_analysis'
  end
  
  # Display the permissions error page
  def permissions_error
    @error_message = params[:error_message] || "Your QuickBooks account lacks the necessary permissions."
    render 'quickbooks/data/permissions_error'
  end
  
  # Display the analysis report
  def analysis_report
    # Get analysis from database using ID stored in session
    analysis_id = session[:current_analysis_id]
    @analysis = QuickbooksAnalysis.find_by(id: analysis_id)
    
    # If no analysis found, check for the most recent one for this profile
    if @analysis.nil? && session[:quickbooks]&.[]("realm_id").present?
      profile = QuickbooksProfile.find_by(realm_id: session[:quickbooks]["realm_id"])
      @analysis = profile&.analyses&.recent&.first
    end
    
    if @analysis.nil?
      redirect_to quickbooks_start_analysis_path, alert: "No analysis results found. Please start a new analysis."
      return
    end
    
    # Get the profile for company name
    @profile = @analysis.quickbooks_profile
    
    # Set up variables for the template
    @start_date = @analysis.start_date
    @end_date = @analysis.end_date
    @detection_rules = @analysis.detection_rules
    @transactions = @analysis.transactions_data
    
    # Get company name from different sources, prioritize results that may have come from the job
    stored_account_name = @analysis.results['account_name'] || @analysis.results[:account_name]
    @company_name = stored_account_name.presence || @profile&.company_name || "QuickBooks Account"
    
    # Build analysis results hash with proper format
    @analysis_results = {
      total_transactions: @analysis.total_transactions,
      total_amount: @analysis.total_amount,
      risk_score: @analysis.risk_score,
      flagged_transactions: @analysis.flagged_transactions,
      account_name: @company_name
    }
    
    # Process transaction dates if needed
    if @analysis_results[:flagged_transactions].present?
      @analysis_results[:flagged_transactions].each do |transaction|
        if transaction['date'].is_a?(String) || transaction[:date].is_a?(String)
          date_string = transaction['date'] || transaction[:date]
          parsed_date = Date.parse(date_string) rescue date_string
          transaction['date'] = parsed_date if transaction.key?('date')
          transaction[:date] = parsed_date if transaction.key?(:date)
        end
      end
    end
    
    # Render the report
    render 'quickbooks/data/analysis_report'
  end
  
  # Test connection to QuickBooks API
  def test_connection
    # Get the QuickBooks service
    service = quickbooks_service
    return if service.nil?
    
    @test_results = {
      timestamp: Time.current,
      tests: []
    }
    
    # Test 1: Basic connection test
    begin
      connection_result = service.test_connectivity
      @test_results[:tests] << {
        name: "Basic Connectivity Test",
        result: connection_result ? "Success" : "Failed",
        details: "Connection to QuickBooks API was #{connection_result ? 'successful' : 'unsuccessful'}"
      }
    rescue => e
      @test_results[:tests] << {
        name: "Basic Connectivity Test",
        result: "Error",
        details: "Error: #{e.message}"
      }
    end
    
    # Test 2: Permission verification
    begin
      permissions_result, error_message = service.verify_permissions
      @test_results[:tests] << {
        name: "Permissions Verification",
        result: permissions_result ? "Success" : "Failed",
        details: permissions_result ? "All required permissions granted" : "Missing permissions: #{error_message}"
      }
    rescue => e
      @test_results[:tests] << {
        name: "Permissions Verification",
        result: "Error",
        details: "Error: #{e.message}"
      }
    end
    
    # Test 3: Fetch a small amount of transaction data
    begin
      transactions = service.fetch_transactions(30.days.ago.to_date, Date.today)
      @test_results[:tests] << {
        name: "Transaction Retrieval (Last 30 Days)",
        result: transactions.present? ? "Success" : "No Data",
        details: transactions.present? ? "Retrieved #{transactions.length} transactions" : "No transactions found in the last 30 days"
      }
      @test_results[:transaction_count] = transactions.length
    rescue => e
      @test_results[:tests] << {
        name: "Transaction Retrieval",
        result: "Error",
        details: "Error: #{e.message}"
      }
    end
    
    # Render the results
    render 'quickbooks/data/test_connection'
  end

  # Fetch and analyze transaction data
  def analyze
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 90.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    
    # Validate date range
    if @start_date > @end_date
      flash[:alert] = "Start date must be before end date"
      redirect_to quickbooks_start_analysis_path
      return
    end
    
    # Store selected detection rules
    @detection_rules = {
      unusual_spending: params[:unusual_spending] == "1",
      duplicate_transactions: params[:duplicate_transactions] == "1",
      round_numbers: params[:round_numbers] == "1",
      new_vendors: params[:new_vendors] == "1",
      outside_hours: params[:outside_hours] == "1",
      end_period: params[:end_period] == "1"
    }
    
    Rails.logger.debug "Initializing analysis for QuickBooks data from #{@start_date} to #{@end_date}"
    Rails.logger.debug "Detection rules: #{@detection_rules.inspect}"
    
    # Get the profile
    realm_id = session[:quickbooks]&.[]("realm_id")
    profile = QuickbooksProfile.find_by(realm_id: realm_id)
    
    if profile.nil?
      flash[:alert] = "QuickBooks profile not found. Please reconnect."
      redirect_to quickbooks_start_analysis_path(skip_validation: true)
      return
    end
    
    # Generate a unique session identifier for this analysis
    session[:analysis_session_id] = SecureRandom.uuid
    
    # Create an initial analysis record in the database
    analysis = QuickbooksAnalysis.create(
      quickbooks_profile_id: profile.id,
      session_id: session[:analysis_session_id],
      start_date: @start_date,
      end_date: @end_date,
      detection_rules: @detection_rules,
      status_progress: 0,
      status_message: "Starting analysis...",
      status_updated_at: Time.current
    )
    
    Rails.logger.info "Created initial analysis record for session: #{session[:analysis_session_id]}"
    
    # Start the background job
    QuickbooksAnalysisJob.perform_later(
      profile.id, 
      @start_date, 
      @end_date, 
      @detection_rules, 
      session[:analysis_session_id]
    )
    
    # Redirect to a progress page
    redirect_to quickbooks_analysis_progress_path
  end
  
  # Show analysis progress
  def analysis_progress
    render 'quickbooks/data/analysis_progress'
  end
  
  # API endpoint to check analysis status
  def analysis_status
    session_id = session[:analysis_session_id]
    
    if session_id.blank?
      render json: { error: "No analysis in progress" }, status: :not_found
      return
    end
    
    # Get status from database
    analysis = QuickbooksAnalysis.find_by(session_id: session_id)
    
    if analysis.nil?
      render json: { progress: 0, message: "Starting analysis..." }, status: :ok
      return
    end
    
    # Build status object
    status = {
      'progress' => analysis.status_progress || 0,
      'message' => analysis.status_message || "Processing...",
      'timestamp' => analysis.status_updated_at&.to_i || Time.current.to_i,
      'success' => analysis.status_success
    }
    
    # If analysis is complete, set the redirect URL
    if analysis.status_progress == 100 && analysis.status_success == true
      session[:current_analysis_id] = analysis.id.to_s
      status['redirect_url'] = quickbooks_analysis_report_path
      Rails.logger.info "Analysis complete. Setting redirect to report path."
    end
    
    render json: status, status: :ok
  end
  
  private
  
  def ensure_quickbooks_connected
    # Skip connection check if explicitly requested
    return if params[:skip_validation] == 'true'
    
    realm_id = session[:quickbooks]&.[]("realm_id")
    
    unless realm_id.present?
      redirect_to root_path, alert: "Please connect to QuickBooks first."
      return
    end
    
    # Verify profile exists and has valid token
    profile = QuickbooksProfile.find_by(realm_id: realm_id)
    
    if profile.nil?
      session.delete(:quickbooks)
      redirect_to root_path, alert: "Your QuickBooks profile was not found. Please connect again."
      return
    end
    
    if profile.access_token.blank?
      # Allow proceeding to start_analysis, but with skip_validation to avoid loops
      if action_name == 'start_analysis'
        params[:skip_validation] = 'true'
      else
        redirect_to quickbooks_start_analysis_path(skip_validation: true), 
          alert: "Your QuickBooks access token is missing. Some features may be limited."
      end
      return
    end
    
    if profile.token_expired?
      begin
        redirect_to quickbooks_refresh_token_path, alert: "Your QuickBooks access token has expired. Refreshing..."
      rescue => e
        Rails.logger.error "Error during token refresh redirect: #{e.message}"
        # Allow proceeding to start_analysis, but with skip_validation to avoid loops
        params[:skip_validation] = 'true'
      end
      return
    end
  end
  
  def quickbooks_service
    realm_id = session[:quickbooks]&.[]("realm_id")
    
    # Ensure we have a realm ID
    if realm_id.blank?
      flash[:alert] = "Missing QuickBooks company ID. Please reconnect."
      # Use redirect_to instead of render, and make sure we're returning rather than continuing
      redirect_to quickbooks_start_analysis_path(skip_validation: true)
      return nil
    end
    
    # Find the profile with the given realm ID
    profile = QuickbooksProfile.find_by(realm_id: realm_id)
    
    if profile.nil?
      flash[:alert] = "QuickBooks profile not found. Please reconnect."
      redirect_to quickbooks_start_analysis_path(skip_validation: true)
      return nil
    end
    
    # Check if the token is expired
    if profile.token_expired?
      redirect_to quickbooks_refresh_token_path, alert: "Your QuickBooks access token has expired. Refreshing..."
      return nil
    end
    
    # Check if access token is present
    if profile.access_token.blank?
      flash[:alert] = "QuickBooks access token is missing. Please reconnect."
      redirect_to quickbooks_start_analysis_path(skip_validation: true)
      return nil
    end
    
    # Create the service - use rescue block to catch any token parsing errors
    begin
      Rails.logger.debug "Creating QuickbooksService for realm_id: #{profile.realm_id}"
      Rails.logger.debug "Access token present: #{profile.access_token.present?}"
      
      decoded_token = profile.access_token
      # Validate the token format before using it
      if decoded_token.is_a?(String) && decoded_token.length > 20
        @quickbooks_service ||= QuickbooksService.new(
          access_token: decoded_token,
          realm_id: profile.realm_id
          # Don't pass refresh_token or expires_at, QboApi doesn't accept them
        )
      else
        Rails.logger.error "Invalid token format detected: #{decoded_token.class} (#{decoded_token.to_s[0..10]}...)"
        # Clear invalid token and request reconnect
        profile.update(access_token: nil, token_expires_at: nil, active: false)
        flash[:alert] = "Invalid QuickBooks token format. Please reconnect your account."
        redirect_to quickbooks_start_analysis_path(skip_validation: true)
        return nil
      end
    rescue ArgumentError => e
      Rails.logger.error "ArgumentError creating QuickbooksService: #{e.message}"
      flash[:alert] = "Error connecting to QuickBooks: #{e.message}"
      redirect_to quickbooks_start_analysis_path(skip_validation: true)
      return nil
    rescue => e
      Rails.logger.error "Unexpected error creating QuickbooksService: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "Unexpected error connecting to QuickBooks. Please try reconnecting."
      redirect_to quickbooks_start_analysis_path(skip_validation: true)
      return nil
    end
  end
  
  def analyze_transactions(transactions, detection_rules = {})
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
    
    # Return analysis results with string keys to ensure JSON compatibility
    {
      'flagged_transactions' => flagged,
      'total_transactions' => transactions.length,
      'total_amount' => total_amount,
      'risk_score' => flagged.empty? ? 0 : rand(25..65)
    }
  end
end