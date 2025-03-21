class Lead
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :company, :string
  attribute :plan, :string
  attribute :newsletter, :boolean
  
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end