class ImportsController < ApplicationController
  def new
    # Show the import form
  end
  
  def create
    # Validate that a file was uploaded
    unless params[:file].present?
      flash[:alert] = "Please select a CSV file to upload"
      render :new
      return
    end
    
    # Check file type
    unless params[:file].content_type == "text/csv" || 
           params[:file].original_filename.ends_with?(".csv")
      flash[:alert] = "File must be a CSV"
      render :new
      return
    end
    
    # Get date range from params
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 90.days.ago.to_date
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.today
    
    # Validate date range
    if start_date > end_date
      flash[:alert] = "Start date must be before end date"
      render :new
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
    
    # Generate a unique session identifier for this analysis
    session[:analysis_session_id] = SecureRandom.uuid
    session[:import_source] = "csv"
    
    # Create an initial analysis record in the database
    analysis = QuickbooksAnalysis.create(
      session_id: session[:analysis_session_id],
      start_date: start_date,
      end_date: end_date,
      detection_rules: @detection_rules,
      status_progress: 0,
      status_message: "Starting CSV import...",
      status_updated_at: Time.current,
      source: "csv"
    )
    
    # Enqueue the job to process the CSV in the background
    CsvAnalysisJob.perform_later(
      params[:file].tempfile.path,
      start_date,
      end_date,
      @detection_rules,
      session[:analysis_session_id],
      params[:mapping_format] || "standard"
    )
    
    # Redirect to progress page
    redirect_to analysis_progress_path
  end
  
  def mapping
    # If file is uploaded, detect headers and suggest mapping
    if params[:file].present?
      begin
        # Check if we have a real file or a test fixture
        path = params[:file].respond_to?(:tempfile) ? params[:file].tempfile.path : params[:file].path
        
        csv = CSV.read(path, headers: true)
        @headers = csv.headers
        
        # Detect format based on headers
        service = CsvImportService.new
        @detected_format = service.detect_format(@headers)
        @mapping = CsvImportService::FORMATS[@detected_format]
        
        # Store the uploaded file temporarily
        @temp_file_path = path
        session[:temp_csv_path] = @temp_file_path
        
        render :mapping
      rescue => e
        Rails.logger.error "CSV import error: #{e.message}\n#{e.backtrace.join("\n")}"
        flash[:alert] = "Error reading CSV file: #{e.message}"
        redirect_to new_import_path
      end
    else
      flash[:alert] = "Please select a CSV file to upload"
      redirect_to new_import_path
    end
  end
  
  def preview
    if params[:file].present? || session[:temp_csv_path].present?
      file_path = params[:file]&.tempfile&.path || session[:temp_csv_path]
      
      if file_path.present? && File.exist?(file_path)
        # Create mapping from params or use default
        mapping = {}
        if params[:mapping].present?
          CsvImportService::TRANSACTION_FIELDS.each_key do |field|
            mapping[field] = params[:mapping][field] if params[:mapping][field].present?
          end
        end
        
        # Use specified format or custom mapping
        if params[:format].present? && params[:format] != "custom"
          service = CsvImportService.new(params[:format].to_sym)
        else
          service = CsvImportService.new(:standard, mapping)
        end
        
        begin
          # Parse first 10 rows for preview
          @transactions = service.parse_file(file_path).first(10)
          
          # Store mapping in session for later use
          session[:csv_mapping] = mapping.present? ? mapping : service.mapping
          session[:csv_format] = params[:format] || "standard"
          
          render :preview
        rescue => e
          flash[:alert] = "Error parsing CSV file: #{e.message}"
          redirect_to new_import_path
        end
      else
        flash[:alert] = "CSV file not found. Please upload it again."
        redirect_to new_import_path
      end
    else
      flash[:alert] = "Please select a CSV file to upload"
      redirect_to new_import_path
    end
  end
  
  # Show analysis progress
  def progress
    render 'analysis/progress'
  end
  
  # API endpoint to check analysis status
  def status
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
      status['redirect_url'] = analysis_report_path
      Rails.logger.info "Analysis complete. Setting redirect to report path."
    end
    
    render json: status, status: :ok
  end
  
  def analysis_report
    # Get analysis from database using ID stored in session
    analysis_id = session[:current_analysis_id]
    @analysis = QuickbooksAnalysis.find_by(id: analysis_id)
    
    if @analysis.nil?
      redirect_to new_import_path, alert: "No analysis results found. Please start a new analysis."
      return
    end
    
    # Set up variables for the template
    @start_date = @analysis.start_date
    @end_date = @analysis.end_date
    @detection_rules = @analysis.detection_rules
    @transactions = @analysis.transactions_data
    
    # Set company name (or default to CSV Import)
    @company_name = "CSV Import"
    
    # Build analysis results hash with proper format
    @analysis_results = @analysis.results
    
    # Process transaction dates if needed
    if @analysis_results['flagged_transactions'].present?
      @analysis_results['flagged_transactions'].each do |transaction|
        if transaction['date'].is_a?(String)
          begin
            transaction['date'] = Date.parse(transaction['date'])
          rescue
            # Keep as string if unparseable
          end
        end
      end
    end
    
    # Render the report
    render 'analysis/report'
  end
end