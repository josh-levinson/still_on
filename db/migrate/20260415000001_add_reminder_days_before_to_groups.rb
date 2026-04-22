class AddReminderDaysBeforeToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :reminder_days_before, :integer, default: 2, null: false
  end
end
