class RemoveRefAndNameFromCostCode < ActiveRecord::Migration
  def change
    drop_column :name, :ref
  end
end
