class CreateQuickbooksProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :quickbooks_profiles do |t|
      t.integer :user_id
      t.string :realm_id
      t.json :profile_data
      t.datetime :last_updated
      t.string :access_token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.datetime :connected_at
      t.boolean :active, default: true
      t.string :email
      t.string :phone
      t.string :first_name
      t.string :last_name
      t.string :company_name
      t.string :address
      t.string :city
      t.string :region
      t.string :postal_code
      t.string :country
      t.string :last_connection_status

      t.timestamps
    end
    
    # Add indices for faster lookups
    add_index :quickbooks_profiles, :realm_id, unique: true
    add_index :quickbooks_profiles, :user_id
    add_index :quickbooks_profiles, :email
    add_index :quickbooks_profiles, :company_name
    add_index :quickbooks_profiles, :active
  end
end
