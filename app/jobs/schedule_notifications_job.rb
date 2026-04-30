class ScheduleNotificationsJob < ApplicationJob
  queue_as :default

  EVENT_REMINDER_MIN_HOURS_AHEAD = 3
  QUORUM_ALERT_HOURS_BEFORE = 24
  LOCAL_DELIVERY_HOUR = 9

  def perform
    Group.find_each do |group|
      schedule_rsvp_reminders(group)
      schedule_event_reminders(group)
      schedule_quorum_alerts(group)
    end
  end

  private

  def schedule_rsvp_reminders(group)
    target = group.reminder_days_before.days.from_now.in_time_zone(group.time_zone)
    window = target.beginning_of_day..target.end_of_day
    deliver_at = local_delivery_time(group)

    occurrences_for(group, window).each do |occurrence|
      SendRsvpReminderJob.set(wait_until: deliver_at).perform_later(occurrence.id)
    end
  end

  def schedule_event_reminders(group)
    now_local = Time.current.in_time_zone(group.time_zone)
    window = (Time.current + EVENT_REMINDER_MIN_HOURS_AHEAD.hours)..now_local.end_of_day
    deliver_at = local_delivery_time(group)

    occurrences_for(group, window).each do |occurrence|
      SendEventReminderJob.set(wait_until: deliver_at).perform_later(occurrence.id)
    end
  end

  def schedule_quorum_alerts(group)
    window = QUORUM_ALERT_HOURS_BEFORE.hours.from_now..(QUORUM_ALERT_HOURS_BEFORE + 2).hours.from_now
    deliver_at = local_delivery_time(group)

    occurrences_for(group, window).includes(:event).each do |occurrence|
      next if occurrence.event.quorum.blank?

      SendQuorumAlertJob.set(wait_until: deliver_at).perform_later(occurrence.id)
    end
  end

  def occurrences_for(group, window)
    EventOccurrence.scheduled
      .joins(:event)
      .where(events: { group_id: group.id }, start_time: window)
  end

  def local_delivery_time(group)
    now_local = Time.current.in_time_zone(group.time_zone)
    target = now_local.change(hour: LOCAL_DELIVERY_HOUR)
    target < now_local ? Time.current : target
  end
end
