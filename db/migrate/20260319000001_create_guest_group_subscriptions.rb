class CreateGuestGroupSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :guest_group_subscriptions, id: :uuid do |t|
      t.references :group, null: false, foreign_key: true, type: :uuid
      t.string :phone_number, null: false

      t.timestamps
    end

    add_index :guest_group_subscriptions, [ :group_id, :phone_number ], unique: true
  end
end
