class SendEventReminderJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: [ :group, :created_by ], rsvps: :user)
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"
    return if occurrence.start_time < Time.current

    event = occurrence.event
    local_time = occurrence.start_time.in_time_zone(event.group.time_zone)
    time_str = "#{local_time.strftime("%-I:%M %p")} #{local_time.zone}"
    location = occurrence.location.presence || event.location.presence
    message = build_message(event.title, time_str, location)
    message += "\n\n#{occurrence.notes}" if occurrence.notes.present?
    subject = "#{event.title} is today"

    confirmed_recipients(occurrence).each do |recipient|
      notify(phone: recipient[:phone], email: recipient[:email], subject: subject, body: message)
    end
  end

  private

  def confirmed_recipients(occurrence)
    recipients = occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).filter_map do |rsvp|
      if rsvp.user.present?
        next unless NotificationPreference.allows?(rsvp.user, :event_day_reminders)
        phone = rsvp.user.phone_number.presence
        email = rsvp.user.email.presence
      else
        phone = rsvp.guest_phone.presence
        email = rsvp.email.presence
      end

      next if phone.blank? && email.blank?

      { phone: phone, email: email }
    end

    ensure_organizer_included(recipients, occurrence)
  end

  def ensure_organizer_included(recipients, occurrence)
    organizer = occurrence.event.created_by
    return recipients unless NotificationPreference.allows?(organizer, :event_day_reminders)

    phone = organizer.phone_number.presence
    email = organizer.email.presence
    return recipients if phone.blank? && email.blank?
    return recipients if phone && recipients.any? { |r| r[:phone] == phone }

    recipients << { phone: phone, email: email }
  end

  def build_message(title, time_str, location)
    msg = "#{title} is happening today at #{time_str}"
    msg += " at #{location}" if location.present?
    msg + ". See you there!"
  end
end
