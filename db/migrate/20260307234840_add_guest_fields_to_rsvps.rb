class AddGuestFieldsToRsvps < ActiveRecord::Migration[8.1]
  def change
    # Make user_id optional — guest RSVPs have no account
    change_column_null :rsvps, :user_id, true

    add_column :rsvps, :guest_name, :string
    add_column :rsvps, :guest_phone, :string

    # Replace the blanket unique index with a partial one that only applies
    # when a real user is present (NULLs are not compared as equal in SQLite)
    remove_index :rsvps, [ :event_occurrence_id, :user_id ]
    add_index :rsvps, [ :event_occurrence_id, :user_id ],
              unique: true,
              where: "user_id IS NOT NULL",
              name: "index_rsvps_on_occurrence_and_user"

    # Prevent duplicate guest RSVPs for the same phone + occurrence
    add_index :rsvps, [ :event_occurrence_id, :guest_phone ],
              unique: true,
              where: "guest_phone IS NOT NULL",
              name: "index_rsvps_on_occurrence_and_guest_phone"
  end
end
