module LandingPages
  class VariantsController < ApplicationController
    include AnalyticsTracking
    
    # Different landing page variants for A/B testing
    # Each method corresponds to a different landing page variant
    
    def cfo
      # Landing page targeting CFOs and financial decision makers
      track_event('landing_page_view', {
        variant: 'cfo',
        source: params[:source],
        campaign: params[:campaign],
        medium: params[:medium]
      })
    end
    
    def small_business
      # Landing page targeting small business owners
      track_event('landing_page_view', {
        variant: 'small_business',
        source: params[:source],
        campaign: params[:campaign],
        medium: params[:medium]
      })
    end
    
    def quickbooks
      # Landing page specific to QuickBooks users
      track_event('landing_page_view', {
        variant: 'quickbooks',
        source: params[:source],
        campaign: params[:campaign],
        medium: params[:medium]
      })
    end
  end
end