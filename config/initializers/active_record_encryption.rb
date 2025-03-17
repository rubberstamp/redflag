# Configure ActiveRecord Encryption for sensitive token data
Rails.application.config.to_prepare do
  # Use hardcoded keys for all environments for simplicity
  # In a real app, use proper key management in production
  
  # Configure encryption with direct keys
  ActiveRecord::Encryption.configure(
    primary_key: "development_key_7b26ecf0a6c673fc0dbb48faa92df1a9",
    deterministic_key: "deterministic_key_for_dev_environment_32bytes",
    key_derivation_salt: "dev_key_derivation_salt_that_is_at_least_32b"
  )
  
  Rails.logger.debug "Active Record Encryption configured for #{Rails.env} environment"
end