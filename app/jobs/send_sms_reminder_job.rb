class SendSmsReminderJob < ApplicationJob
  queue_as :default

  def perform(event_occurrence_id)
    occurrence = EventOccurrence.includes(event: { group: :group_memberships }).find(event_occurrence_id)
    return unless occurrence.status == "scheduled"

    event = occurrence.event
    date_str = occurrence.start_time.strftime("%A, %B %-d")
    rsvp_url = Rails.application.routes.url_helpers.event_occurrence_rsvps_url(
      event_id: event.id,
      event_occurrence_id: occurrence.id,
      host: Rails.application.credentials.dig(:app, :host) || ENV["APP_HOST"] || "localhost:3000"
    )

    message = "Still on for #{event.name} on #{date_str}? RSVP here: #{rsvp_url}"

    recipients = occurrence.event.group.group_memberships
                           .includes(:user)
                           .map(&:user)
                           .select { |u| u.phone_number.present? }

    recipients.each do |user|
      SmsService.send_message(to: user.phone_number, body: message)
    end
  end
end
