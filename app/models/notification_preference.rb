class NotificationPreference < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true

  def self.allows?(user, notification_type)
    pref = user.notification_preference
    return true if pref.nil?
    pref.public_send(notification_type)
  end
end
