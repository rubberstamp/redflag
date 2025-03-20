class CreateCsvUploads < ActiveRecord::Migration[8.0]
  def change
    create_table :csv_uploads do |t|
      t.string :session_id, null: false

      t.timestamps
    end
    
    add_index :csv_uploads, :session_id
  end
end
