class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.boolean :rsvp_reminders,             null: false, default: true
      t.boolean :event_day_reminders,        null: false, default: true
      t.boolean :quorum_alerts,              null: false, default: true
      t.boolean :cancellation_notifications, null: false, default: true
      t.boolean :event_change_notifications, null: false, default: true
      t.timestamps
    end
  end
end
