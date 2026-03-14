class SendEventReminderJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: [], rsvps: :user)
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"
    return if occurrence.start_time <= Time.current

    event = occurrence.event
    time_str = occurrence.start_time.strftime("%-I:%M %p")
    location = occurrence.location.presence || event.location.presence
    message = build_message(event.title, time_str, location)

    confirmed_phones(occurrence).each do |phone|
      next if SmsOptOut.opted_out?(phone)

      SmsService.send_message(to: phone, body: message)
    end
  end

  private

  def confirmed_phones(occurrence)
    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).filter_map do |rsvp|
      rsvp.user&.phone_number.presence || rsvp.guest_phone.presence
    end
  end

  def build_message(title, time_str, location)
    msg = "#{title} is happening today at #{time_str}"
    msg += " at #{location}" if location.present?
    msg + ". See you there!"
  end
end
