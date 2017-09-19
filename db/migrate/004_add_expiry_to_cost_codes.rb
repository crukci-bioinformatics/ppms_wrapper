class AddExpiryToCostCodes < ActiveRecord::Migration
  def change
    add_column :cost_codes, :expiration, :date
  end
end
