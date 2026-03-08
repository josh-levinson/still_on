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

    confirmed_attendees(occurrence).each do |user|
      SmsService.send_message(to: user.phone_number, body: message)
    end
  end

  private

  def confirmed_attendees(occurrence)
    occurrence.rsvps
      .where(status: %w[attending maybe])
      .includes(:user)
      .map(&:user)
      .select { |u| u.phone_number.present? }
  end

  def build_message(title, time_str, location)
    msg = "#{title} is happening today at #{time_str}"
    msg += " at #{location}" if location.present?
    msg + ". See you there!"
  end
end
