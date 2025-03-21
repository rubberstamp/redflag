class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Include analytics tracking
  include AnalyticsTracking
  
  # Track page views for all controller actions
  before_action :track_controller_action
  
  private
  
  def track_controller_action
    track_page_view("#{controller_name}##{action_name}")
  end
end
