class SendEventChangeNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id, changed_fields, old_start_time_iso, old_location)
    occurrence = EventOccurrence
      .includes(event: :group, rsvps: :user)
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"

    event = occurrence.event
    old_start_time = Time.parse(old_start_time_iso)

    message = build_message(event, occurrence, changed_fields, old_start_time, old_location)
    subject = "#{event.title} has been updated"

    attending_recipients(occurrence).each do |recipient|
      rsvp_link = rsvp_url_for(occurrence, phone: recipient[:phone])
      notify(
        phone: recipient[:phone],
        email: recipient[:email],
        subject: subject,
        body: "#{message} RSVP: #{rsvp_link}"
      )
    end
  end

  private

  def attending_recipients(occurrence)
    occurrence.rsvps.where(status: %w[attending maybe]).includes(:user).filter_map do |rsvp|
      if rsvp.user.present?
        next if rsvp.user.phone_verified_at.blank? && rsvp.user.email.blank?

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

  def build_message(event, occurrence, changed_fields, old_start_time, old_location)
    parts = []
    tz = occurrence.event.group.time_zone

    if changed_fields.include?("start_time")
      old_local = old_start_time.in_time_zone(tz)
      new_local = occurrence.start_time.in_time_zone(tz)
      old_date_str = "#{old_local.strftime("%A, %b %-d at %-I:%M %p")} #{old_local.zone}"
      new_date_str = "#{new_local.strftime("%A, %b %-d at %-I:%M %p")} #{new_local.zone}"
      parts << "#{event.title} on #{old_date_str} has moved to #{new_date_str}."
    end

    if changed_fields.include?("location")
      new_location = occurrence.location.presence || occurrence.event.location.presence || "TBD"
      parts << "#{event.title} location has changed to #{new_location}."
    end

    "Update: #{parts.join(" ")}"
  end

  def rsvp_url_for(occurrence, phone: nil)
    token = occurrence.invite_token(phone: phone)
    host = Rails.application.credentials.dig(:app, :host) || ENV["APP_HOST"] || "localhost:3000"
    Rails.application.routes.url_helpers.guest_rsvp_url(token, host: host)
  end
end
