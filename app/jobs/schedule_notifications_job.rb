class ScheduleNotificationsJob < ApplicationJob
  queue_as :default

  RSVP_REMINDER_DAYS_BEFORE = 2
  EVENT_REMINDER_MIN_HOURS_AHEAD = 3

  def perform
    schedule_rsvp_reminders
    schedule_event_reminders
  end

  private

  def schedule_rsvp_reminders
    window = days_from_now_window(RSVP_REMINDER_DAYS_BEFORE)
    EventOccurrence.scheduled.where(start_time: window).each do |occurrence|
      SendRsvpReminderJob.perform_later(occurrence.id)
    end
  end

  def schedule_event_reminders
    window = EVENT_REMINDER_MIN_HOURS_AHEAD.hours.from_now..Time.current.end_of_day
    EventOccurrence.scheduled.where(start_time: window).each do |occurrence|
      SendEventReminderJob.perform_later(occurrence.id)
    end
  end

  def days_from_now_window(days)
    target = days.days.from_now
    target.beginning_of_day..target.end_of_day
  end
end
