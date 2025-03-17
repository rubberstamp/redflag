class AddCompanyInfoToQuickbooksProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :quickbooks_profiles, :legal_name, :string
    add_column :quickbooks_profiles, :company_info, :json
    add_column :quickbooks_profiles, :fiscal_year_start_month, :integer
  end
end
