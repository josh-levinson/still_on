class SendCancellationNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: [], rsvps: :user)
      .find(event_occurrence_id)

    event = occurrence.event
    date_str = occurrence.start_time.strftime("%A, %b %-d at %-I:%M %p")
    message = "#{event.title} on #{date_str} has been cancelled. Sorry for the inconvenience!"

    attending_phones(occurrence).each do |phone|
      next if SmsOptOut.opted_out?(phone)

      SmsService.send_message(to: phone, body: message)
    end
  end

  private

  def attending_phones(occurrence)
    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).filter_map do |rsvp|
      phone = rsvp.user&.phone_number.presence || rsvp.guest_phone.presence
      next unless phone.present?
      next unless rsvp.user.nil? || rsvp.user.phone_verified_at.present?

      phone
    end
  end
end
