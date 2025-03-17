class AddTransactionsDataToQuickbooksAnalyses < ActiveRecord::Migration[8.0]
  def change
    add_column :quickbooks_analyses, :transactions_data, :json
  end
end
