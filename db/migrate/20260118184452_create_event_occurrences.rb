class CreateEventOccurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :event_occurrences, id: :uuid do |t|
      t.references :event, null: false, foreign_key: true, type: :uuid
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :location
      t.string :status, default: 'scheduled', null: false
      t.integer :max_attendees
      t.text :notes

      t.timestamps
    end

    add_index :event_occurrences, [ :event_id, :start_time ]
    add_index :event_occurrences, :start_time
    add_index :event_occurrences, :status
  end
end
