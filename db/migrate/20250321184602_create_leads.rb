class CreateLeads < ActiveRecord::Migration[8.0]
  def change
    create_table :leads do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :company
      t.string :plan
      t.boolean :newsletter

      t.timestamps
    end
  end
end
