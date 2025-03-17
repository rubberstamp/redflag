# Standard cookie-based session store with a custom key
Rails.application.config.session_store :cookie_store, key: '_redflag_session'

# Note: To avoid cookie overflow errors, large data like analysis results
# should be stored in the database instead of the session