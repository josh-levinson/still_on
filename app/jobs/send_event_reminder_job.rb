class SendEventReminderJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: :group, rsvps: :user)
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"
    return if occurrence.start_time <= Time.current

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
    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).filter_map do |rsvp|
      if rsvp.user.present?
        phone = rsvp.user.phone_number.presence
        email = rsvp.user.email.presence
      else
        phone = rsvp.guest_phone.presence
        email = rsvp.email.presence
      end

      next if phone.blank? && email.blank?

      { phone: phone, email: email }
    end
  end

  def build_message(title, time_str, location)
    msg = "#{title} is happening today at #{time_str}"
    msg += " at #{location}" if location.present?
    msg + ". See you there!"
  end
end
