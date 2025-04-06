class AddPhoneAndCompanySizeToLeads < ActiveRecord::Migration[8.0]
  def change
    add_column :leads, :phone, :string
    add_column :leads, :company_size, :string
    add_column :leads, :cfo_consultation, :boolean
  end
end
