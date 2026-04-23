require "test_helper"

class NotificationPreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
  end

  # ---- GET /notification_preference/edit ----

  test "edit redirects to sign-in when not authenticated" do
    get edit_notification_preference_path
    assert_redirected_to onboarding_splash_path
  end

  test "edit renders successfully when signed in" do
    sign_in(@user)
    get edit_notification_preference_path
    assert_response :success
  end

  test "edit renders with existing preferences" do
    NotificationPreference.create!(user: @user, rsvp_reminders: false)
    sign_in(@user)
    get edit_notification_preference_path
    assert_response :success
  end

  # ---- PATCH /notification_preference ----

  test "update redirects to sign-in when not authenticated" do
    patch notification_preference_path, params: { notification_preference: { rsvp_reminders: false } }
    assert_redirected_to onboarding_splash_path
  end

  test "update creates preferences when none exist" do
    sign_in(@user)
    assert_difference "NotificationPreference.count", 1 do
      patch notification_preference_path, params: {
        notification_preference: {
          rsvp_reminders: "0",
          event_day_reminders: "1",
          quorum_alerts: "1",
          cancellation_notifications: "1",
          event_change_notifications: "1"
        }
      }
    end
    assert_redirected_to edit_notification_preference_path
    assert_not @user.reload.notification_preference.rsvp_reminders
  end

  test "update modifies existing preferences" do
    pref = NotificationPreference.create!(user: @user, rsvp_reminders: true, event_day_reminders: true)
    sign_in(@user)
    patch notification_preference_path, params: {
      notification_preference: {
        rsvp_reminders: "0",
        event_day_reminders: "0",
        quorum_alerts: "1",
        cancellation_notifications: "1",
        event_change_notifications: "1"
      }
    }
    assert_redirected_to edit_notification_preference_path
    pref.reload
    assert_not pref.rsvp_reminders
    assert_not pref.event_day_reminders
  end

  test "update sets flash notice on success" do
    sign_in(@user)
    patch notification_preference_path, params: {
      notification_preference: {
        rsvp_reminders: "1",
        event_day_reminders: "1",
        quorum_alerts: "1",
        cancellation_notifications: "1",
        event_change_notifications: "1"
      }
    }
    assert_equal "Notification preferences saved.", flash[:notice]
  end

  test "update re-renders edit when save fails" do
    sign_in(@user)
    mock_pref = NotificationPreference.new(user: @user)
    mock_pref.stub(:update, false) do
      @user.stub(:notification_preference, mock_pref) do
        User.stub(:find_by, @user) do
          patch notification_preference_path, params: {
            notification_preference: {
              rsvp_reminders: "1",
              event_day_reminders: "1",
              quorum_alerts: "1",
              cancellation_notifications: "1",
              event_change_notifications: "1"
            }
          }
        end
      end
    end
    assert_response :unprocessable_entity
  end
end
