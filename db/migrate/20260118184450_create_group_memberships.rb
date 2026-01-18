class CreateGroupMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :group_memberships, id: :uuid do |t|
      t.references :group, null: false, foreign_key: true, type: :uuid
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :role, null: false, default: 'member'
      t.datetime :joined_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.timestamps
    end

    add_index :group_memberships, [ :group_id, :user_id ], unique: true
  end
end
