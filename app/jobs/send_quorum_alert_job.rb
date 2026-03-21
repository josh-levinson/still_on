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
    phone = organizer.phone_verified_at.present? ? organizer.phone_number.presence : nil
    email = organizer.email.presence

    return if phone.blank? && email.blank?

    message = "Heads up: #{event.title} on #{date_str} only has #{count} of " \
              "#{event.quorum} needed. Consider reaching out to your group!"

    notify(
      phone: phone,
      email: email,
      subject: "#{event.title} is below quorum",
      body: message
    )
  end

  def send_attendee_alerts(occurrence, event, date_str)
    message = "Just so you know: #{event.title} on #{date_str} is still looking " \
              "for more people. Invite a friend!"
    subject = "#{event.title} needs more people"

    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).each do |rsvp|
      if rsvp.user.present?
        phone = rsvp.user.phone_verified_at.present? ? rsvp.user.phone_number.presence : nil
        email = rsvp.user.email.presence
      else
        phone = rsvp.guest_phone.presence
        email = rsvp.email.presence
      end

      next if phone.blank? && email.blank?

      notify(phone: phone, email: email, subject: subject, body: message)
    end
  end
end
