class SendQuorumAlertJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id)
    occurrence = EventOccurrence
      .includes(event: :created_by, rsvps: :user)
      .find(event_occurrence_id)

    event = occurrence.event

    return if event.quorum.blank?
    return unless occurrence.status == "scheduled"
    return if occurrence.attending_count >= event.quorum

    date_str = occurrence.start_time.strftime("%A, %b %-d at %-I:%M %p")
    count = occurrence.attending_count

    send_organizer_alert(event, date_str, count)
    send_attendee_alerts(occurrence, event, date_str)
  end

  private

  def send_organizer_alert(event, date_str, count)
    organizer = event.created_by
    phone = organizer.phone_number

    return if phone.blank?
    return if organizer.phone_verified_at.blank?
    return if SmsOptOut.opted_out?(phone)

    message = "Heads up: #{event.title} on #{date_str} only has #{count} of " \
              "#{event.quorum} needed. Consider reaching out to your group!"
    SmsService.send_message(to: phone, body: message)
  end

  def send_attendee_alerts(occurrence, event, date_str)
    message = "Just so you know: #{event.title} on #{date_str} is still looking " \
              "for more people. Invite a friend!"

    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).each do |rsvp|
      phone = rsvp.user&.phone_number.presence || rsvp.guest_phone.presence
      next if phone.blank?
      next if rsvp.user.present? && rsvp.user.phone_verified_at.blank?
      next if SmsOptOut.opted_out?(phone)

      SmsService.send_message(to: phone, body: message)
    end
  end
end
