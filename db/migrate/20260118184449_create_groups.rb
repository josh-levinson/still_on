class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.string :slug, null: false
      t.string :avatar_url
      t.boolean :is_private, default: false, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end

    add_index :groups, :slug, unique: true
  end
end
