class UpdateQuickbooksAnalysesForCsvImport < ActiveRecord::Migration[8.0]
  def change
    # Make quickbooks_profile_id optional
    change_column_null :quickbooks_analyses, :quickbooks_profile_id, true
    
    # Add source field to distinguish between QuickBooks and CSV imports
    add_column :quickbooks_analyses, :source, :string, default: "quickbooks"
    add_index :quickbooks_analyses, :source
    
    # Add index for session_id for faster lookups
    add_index :quickbooks_analyses, :session_id
  end
end
