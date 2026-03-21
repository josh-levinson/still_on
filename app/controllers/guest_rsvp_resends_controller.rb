class GuestRsvpResendsController < ApplicationController
  def new
  end

  def create
    phone_digits = params[:phone].to_s.gsub(/\D/, "").last(10)

    send_rsvp_links(phone_digits) if phone_digits.length == 10

    redirect_to new_guest_rsvp_resend_path,
      notice: "If we have any upcoming events for that number, we'll text you the links."
  end

  private

  def send_rsvp_links(phone_digits)
    phone_e164 = "+1#{phone_digits}"

    upcoming_rsvps = Rsvp
      .joins(:event_occurrence)
      .where("RIGHT(REGEXP_REPLACE(guest_phone, '[^0-9]', '', 'g'), 10) = ?", phone_digits)
      .where(event_occurrences: { status: "scheduled" })
      .where("event_occurrences.start_time > ?", Time.current)
      .includes(event_occurrence: { event: :group })

    upcoming_rsvps.each do |rsvp|
      send_link_for_rsvp(rsvp, phone_e164)
    end
  end

  def send_link_for_rsvp(rsvp, phone_e164)
    occurrence = rsvp.event_occurrence
    token = occurrence.invite_token(phone: phone_e164)
    host = Rails.application.credentials.dig(:app, :host) || ENV.fetch("APP_HOST", "localhost:3000")
    url = Rails.application.routes.url_helpers.guest_rsvp_url(token, host: host)
    date_str = occurrence.start_time.strftime("%b %-d")
    body = "Your RSVP link for #{occurrence.event.title} on #{date_str}: #{url}"
    SmsService.send_message(to: phone_e164, body: body)
  rescue StandardError => e
    Rails.logger.error("[GuestRsvpResends] Failed to send link to #{phone_e164}: #{e.message}")
  end
end
