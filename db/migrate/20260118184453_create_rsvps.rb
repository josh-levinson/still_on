class CreateRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvps, id: :uuid do |t|
      t.references :event_occurrence, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false
      t.integer :guest_count, default: 0, null: false
      t.text :notes

      t.timestamps
    end

    add_index :rsvps, [ :event_occurrence_id, :user_id ], unique: true
    add_index :rsvps, :status
  end
end
