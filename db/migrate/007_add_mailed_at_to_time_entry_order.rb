class AddMailedAtToTimeEntryOrder < ActiveRecord::Migration
  def change
    add_column :mailed_at
  end
end
