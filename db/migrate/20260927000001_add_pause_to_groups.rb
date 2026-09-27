class AddPauseToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :paused_at, :datetime
    add_column :groups, :paused_until, :date
  end
end
