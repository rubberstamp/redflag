class Lead < ApplicationRecord
  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, format: { with: /\A\+?[\d\s\-\(\)]+\z/, message: "format is invalid" }, allow_blank: true
  
  # Company size options - for form select
  COMPANY_SIZE_OPTIONS = [
    "1-10 employees",
    "11-50 employees",
    "51-200 employees",
    "201-500 employees",
    "501-1000 employees",
    "1000+ employees"
  ]
  
  # Helper method to get full name
  def full_name
    "#{first_name} #{last_name}"
  end
  
  # Helper to check if lead has completed both initial and full capture
  def complete_lead?
    email.present? && first_name.present? && last_name.present? && company.present?
  end
  
  # Helper to check if lead has completed only initial capture
  def initial_capture_only?
    email.present? && (first_name.blank? || last_name.blank? || company.blank?)
  end
end