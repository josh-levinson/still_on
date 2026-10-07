class AddInviteTokenToEventOccurrences < ActiveRecord::Migration[8.1]
  def up
    add_column :event_occurrences, :invite_token, :string

    # Backfill existing rows with short, unique, URL-safe tokens.
    say_with_time "Backfilling invite_token" do
      EventOccurrence.reset_column_information
      EventOccurrence.where(invite_token: nil).find_each do |occurrence|
        occurrence.update_columns(invite_token: SecureRandom.urlsafe_base64(8))
      end
    end

    change_column_null :event_occurrences, :invite_token, false
    add_index :event_occurrences, :invite_token, unique: true
  end

  def down
    remove_column :event_occurrences, :invite_token
  end
end
