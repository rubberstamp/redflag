module AnalyticsTracking
  extend ActiveSupport::Concern

  # Track an event with PostHog
  def track_event(event, properties = {})
    # Get the user identifier - prefer a user ID, but use anonymous ID as fallback
    user_id = session[:lead_id].presence || session[:anonymous_id]
    
    # If no identifier exists yet, create an anonymous ID
    if user_id.nil?
      user_id = SecureRandom.uuid
      session[:anonymous_id] = user_id
    end
    
    # Add some default properties
    default_properties = {
      source: request.referer,
      url: request.url,
      path: request.path,
      user_agent: request.user_agent,
      ip_city: request.remote_ip,
      rails_env: Rails.env
    }
    
    # Merge default properties with custom properties
    all_properties = default_properties.merge(properties)

    # Track the event
    begin
      Rails.application.config.posthog.capture({
        distinct_id: user_id,
        event: event,
        properties: all_properties
      })
      Rails.logger.debug "PostHog: Tracked event '#{event}' for user #{user_id}"
    rescue => e
      Rails.logger.error "PostHog: Failed to track event: #{e.message}"
    end
  end

  # Track page views
  def track_page_view(page_name = nil)
    properties = {}
    properties[:page_name] = page_name if page_name.present?
    track_event("page_view", properties)
  end

  # Helper to identify a user with their properties
  def identify_user(user_id, properties = {})
    begin
      Rails.application.config.posthog.identify({
        distinct_id: user_id,
        properties: properties
      })
      Rails.logger.debug "PostHog: Identified user #{user_id}"
    rescue => e
      Rails.logger.error "PostHog: Failed to identify user: #{e.message}"
    end
  end
end