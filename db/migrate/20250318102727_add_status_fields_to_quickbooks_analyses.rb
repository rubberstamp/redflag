class AddStatusFieldsToQuickbooksAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_column :quickbooks_analyses, :session_id, :string
    add_column :quickbooks_analyses, :status_progress, :integer
    add_column :quickbooks_analyses, :status_message, :string
    add_column :quickbooks_analyses, :status_updated_at, :datetime
    add_column :quickbooks_analyses, :status_success, :boolean
    add_column :quickbooks_analyses, :completed, :boolean
  end
end
