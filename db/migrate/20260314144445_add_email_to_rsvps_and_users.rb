class AddEmailToRsvpsAndUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :rsvps, :email, :string
    add_column :users, :email, :string
  end
end
