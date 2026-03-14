class SendEventChangeNotificationJob < ApplicationJob
  queue_as :notifications

  def perform(event_occurrence_id, changed_fields, old_start_time_iso, old_location)
    occurrence = EventOccurrence
      .includes(event: [], rsvps: :user)
      .find(event_occurrence_id)

    return unless occurrence.status == "scheduled"

    event = occurrence.event
    old_start_time = Time.parse(old_start_time_iso)

    message = build_message(event, occurrence, changed_fields, old_start_time, old_location)

    attending_phones(occurrence).each do |phone|
      next if SmsOptOut.opted_out?(phone)

      rsvp_link = rsvp_url_for(occurrence, phone: phone)
      SmsService.send_message(to: phone, body: "#{message} RSVP: #{rsvp_link}")
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

  def build_message(event, occurrence, changed_fields, old_start_time, old_location)
    parts = []

    if changed_fields.include?("start_time")
      old_date_str = old_start_time.strftime("%A, %b %-d at %-I:%M %p")
      new_date_str = occurrence.start_time.strftime("%A, %b %-d at %-I:%M %p")
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
