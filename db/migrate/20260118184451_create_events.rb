class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events, id: :uuid do |t|
      t.references :group, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :description
      t.string :location
      t.integer :default_duration_minutes
      t.string :recurrence_rule
      t.string :recurrence_type, default: 'none', null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end

    add_index :events, :recurrence_type
  end
end
