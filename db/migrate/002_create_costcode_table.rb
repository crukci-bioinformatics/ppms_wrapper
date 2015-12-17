class CreateCostcodeTable < ActiveRecord::Migration
  def change
    create_table :cost_codes do |t|
      t.string :name, null: false, index: true
      t.string :code, null: false, index: true
      t.integer :ref, null: false, index: true
      t.timestamps null: false
    end
  end
end
