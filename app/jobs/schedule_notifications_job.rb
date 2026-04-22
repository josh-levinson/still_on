class ScheduleNotificationsJob < ApplicationJob
  queue_as :default

  EVENT_REMINDER_MIN_HOURS_AHEAD = 3
  QUORUM_ALERT_HOURS_BEFORE = 24

  def perform
    schedule_rsvp_reminders
    schedule_event_reminders
    schedule_quorum_alerts
  end

  private

  def schedule_rsvp_reminders
    Group.distinct.pluck(:reminder_days_before).each do |days|
      window = days_from_now_window(days)
      EventOccurrence.scheduled
        .joins(event: :group)
        .where(groups: { reminder_days_before: days }, start_time: window)
        .each { |occurrence| SendRsvpReminderJob.perform_later(occurrence.id) }
    end
  end

  def schedule_event_reminders
    window = EVENT_REMINDER_MIN_HOURS_AHEAD.hours.from_now..Time.current.end_of_day
    EventOccurrence.scheduled.where(start_time: window).each do |occurrence|
      SendEventReminderJob.perform_later(occurrence.id)
    end
  end

  def schedule_quorum_alerts
    window = QUORUM_ALERT_HOURS_BEFORE.hours.from_now..(QUORUM_ALERT_HOURS_BEFORE + 2).hours.from_now
    EventOccurrence.scheduled.includes(:event).where(start_time: window).each do |occurrence|
      next if occurrence.event.quorum.blank?

      SendQuorumAlertJob.perform_later(occurrence.id)
    end
  end

  def days_from_now_window(days)
    target = days.days.from_now
    target.beginning_of_day..target.end_of_day
  end
end
