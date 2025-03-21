# PostHog analytics configuration
require 'posthog-ruby'

# Initialize the PostHog client
if Rails.env.production? || Rails.env.development?
  Rails.application.config.posthog = PostHog::Client.new({
    api_key: "phc_SfmBYLcBnccB9kMq27UwS7KzI5HMUwySwihgkLAKQe4",
    host: "https://eu.i.posthog.com",
    on_error: Proc.new { |status, msg| Rails.logger.error("PostHog Error: #{status} - #{msg}") }
  })
else
  # In test environment, create a mock client
  Rails.application.config.posthog = PostHog::Client.new({
    api_key: "mock_key",
    host: "https://mock.posthog.com",
    disabled: true
  })
end