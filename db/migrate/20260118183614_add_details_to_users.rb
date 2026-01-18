class AddDetailsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :avatar_url, :string
    add_column :users, :username, :string

    add_index :users, :username, unique: true
  end
end
