class CreateQuickbooksAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :quickbooks_analyses do |t|
      t.references :quickbooks_profile, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.json :detection_rules
      t.json :results

      t.timestamps
    end
  end
end
