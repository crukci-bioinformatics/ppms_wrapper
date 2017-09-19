class AddActiveToCostCodes < ActiveRecord::Migration
  def change
    add_column :cost_codes, :active, :boolean
  end
end
