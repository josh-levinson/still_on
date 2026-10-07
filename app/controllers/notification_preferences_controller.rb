class NotificationPreferencesController < ApplicationController
  before_action :authenticate_user!

  def edit
    @notification_preference = current_user.notification_preference ||
      current_user.build_notification_preference
  end

  def update
    @notification_preference = current_user.notification_preference ||
      current_user.build_notification_preference

    if @notification_preference.update(notification_preference_params)
      redirect_to edit_notification_preference_path, notice: "Notification preferences saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def notification_preference_params
    params.require(:notification_preference).permit(
      :rsvp_reminders,
      :event_day_reminders,
      :quorum_alerts,
      :cancellation_notifications,
      :event_change_notifications
    )
  end
end
