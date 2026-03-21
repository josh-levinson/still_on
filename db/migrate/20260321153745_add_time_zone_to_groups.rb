class AddTimeZoneToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :time_zone, :string, null: false, default: "UTC"
  end
end
