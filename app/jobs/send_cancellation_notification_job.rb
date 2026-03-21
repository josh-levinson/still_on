class SendCancellationNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: [], rsvps: :user)
      .find(event_occurrence_id)

    event = occurrence.event
    date_str = occurrence.start_time.strftime("%A, %b %-d at %-I:%M %p")
    message = "#{event.title} on #{date_str} has been cancelled. Sorry for the inconvenience!"
    subject = "#{event.title} has been cancelled"

    attending_recipients(occurrence).each do |recipient|
      notify(phone: recipient[:phone], email: recipient[:email], subject: subject, body: message)
    end
  end

  private

  def attending_recipients(occurrence)
    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).filter_map do |rsvp|
      if rsvp.user.present?
        phone = rsvp.user.phone_verified_at.present? ? rsvp.user.phone_number.presence : nil
        email = rsvp.user.email.presence
      else
        phone = rsvp.guest_phone.presence
        email = rsvp.email.presence
      end

      next if phone.blank? && email.blank?

      { phone: phone, email: email }
    end
  end
end
