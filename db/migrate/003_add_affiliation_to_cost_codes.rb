class AddAffiliationToCostCodes < ActiveRecord::Migration
  def change
    add_column :cost_codes, :affiliation, :string
  end
end
