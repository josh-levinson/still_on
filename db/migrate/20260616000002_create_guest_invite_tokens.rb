class CreateGuestInviteTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :guest_invite_tokens, id: :uuid do |t|
      t.references :event_occurrence, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.string :phone, null: false

      t.timestamps
    end

    add_index :guest_invite_tokens, :token, unique: true
    add_index :guest_invite_tokens, [ :event_occurrence_id, :phone ], unique: true
  end
end
