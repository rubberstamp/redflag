class Lead < ApplicationRecord
  # Validations
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Helper method to get full name
  def full_name
    "#{first_name} #{last_name}"
  end
end