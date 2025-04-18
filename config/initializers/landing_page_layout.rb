# Configure landing pages to use a dedicated layout without navigation
Rails.application.config.to_prepare do
  # Set landing page controller to use minimal layout
  LandingPages::VariantsController.layout 'landing_page'
end