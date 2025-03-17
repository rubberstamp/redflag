class QuickbooksAnalysis < ApplicationRecord
  belongs_to :quickbooks_profile
  
  # Validations
  validates :quickbooks_profile, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :detection_rules, presence: true
  validates :results, presence: true
  
  # Store transactions data
  attribute :transactions_data, :json
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :for_profile, ->(profile_id) { where(quickbooks_profile_id: profile_id) }
  
  # Convenience methods
  def flagged_transactions
    results&.dig('flagged_transactions') || []
  end
  
  def total_transactions
    results&.dig('total_transactions') || 0
  end
  
  def total_amount
    results&.dig('total_amount') || 0.0
  end
  
  def risk_score
    results&.dig('risk_score') || 0
  end
  
  def date_range_text
    "#{start_date&.strftime('%b %d, %Y')} to #{end_date&.strftime('%b %d, %Y')}"
  end
end
