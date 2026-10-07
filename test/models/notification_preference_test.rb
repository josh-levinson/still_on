require "test_helper"

class NotificationPreferenceTest < ActiveSupport::TestCase
  setup do
    @user = create_user
  end

  test "allows? returns true when user has no preference record" do
    assert NotificationPreference.allows?(@user, :rsvp_reminders)
    assert NotificationPreference.allows?(@user, :event_day_reminders)
    assert NotificationPreference.allows?(@user, :quorum_alerts)
    assert NotificationPreference.allows?(@user, :cancellation_notifications)
    assert NotificationPreference.allows?(@user, :event_change_notifications)
  end

  test "allows? returns true when preference is enabled" do
    NotificationPreference.create!(user: @user, rsvp_reminders: true)
    assert NotificationPreference.allows?(@user.reload, :rsvp_reminders)
  end

  test "allows? returns false when preference is disabled" do
    NotificationPreference.create!(user: @user, rsvp_reminders: false)
    assert_not NotificationPreference.allows?(@user.reload, :rsvp_reminders)
  end

  test "each notification type can be independently disabled" do
    pref = NotificationPreference.create!(
      user: @user,
      rsvp_reminders: false,
      event_day_reminders: true,
      quorum_alerts: false,
      cancellation_notifications: true,
      event_change_notifications: false
    )
    assert_not pref.rsvp_reminders
    assert pref.event_day_reminders
    assert_not pref.quorum_alerts
    assert pref.cancellation_notifications
    assert_not pref.event_change_notifications
  end

  test "is invalid without a user" do
    pref = NotificationPreference.new
    assert_not pref.valid?
    assert_includes pref.errors[:user], "must exist"
  end

  test "enforces one preference record per user" do
    NotificationPreference.create!(user: @user)
    duplicate = NotificationPreference.new(user: @user)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end
end
