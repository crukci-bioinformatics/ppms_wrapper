class CreatePpmsTables < ActiveRecord::Migration
  def change
    create_table :email_raven_maps do |t|
      t.string :email, null: false, index: true
      t.string :raven, null: false, index: true, limit: 32
      t.timestamps null: false
    end
    create_table :time_entry_orders do |t|
      t.belongs_to :time_entry, index: true, null: false
      t.integer :order_id, null: false
      t.timestamps null: false
    end
  end
end
